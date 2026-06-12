// Loot-core SPIR-V parity runner.
// Dispatches the lean-slang-emitted kernel.spv on Vulkan (via volk) and checks
// every output index against the Plausible-verified golden vectors from the Lean
// core. Integer ops are exact across conformant Vulkan implementations, so the
// SPIR-V kernel reproduces the Lean spec bit-for-bit.
#include "volk.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define N 1024u
#define WORKGROUP 64u
#define CK(x) do { VkResult _r = (x); if (_r) { fprintf(stderr, "VK error %d at %s:%d\n", _r, __FILE__, __LINE__); exit(2); } } while (0)

static VkPhysicalDevice phys;
static VkDevice dev;
static uint32_t memTypeHostCoherent;

static uint32_t findMemType(uint32_t bits, VkMemoryPropertyFlags want) {
  VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(phys, &mp);
  for (uint32_t i = 0; i < mp.memoryTypeCount; i++)
    if ((bits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & want) == want) return i;
  fprintf(stderr, "no host-visible coherent memory type\n"); exit(2);
}

typedef struct { VkBuffer buf; VkDeviceMemory mem; void *ptr; VkDeviceSize size; } Buf;

static Buf mkBuf(VkDeviceSize size) {
  Buf b; b.size = size;
  VkBufferCreateInfo bi = { .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO, .size = size,
    .usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, .sharingMode = VK_SHARING_MODE_EXCLUSIVE };
  CK(vkCreateBuffer(dev, &bi, NULL, &b.buf));
  VkMemoryRequirements req; vkGetBufferMemoryRequirements(dev, b.buf, &req);
  VkMemoryAllocateInfo ai = { .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
    .allocationSize = req.size, .memoryTypeIndex = findMemType(req.memoryTypeBits,
      VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) };
  CK(vkAllocateMemory(dev, &ai, NULL, &b.mem));
  CK(vkBindBufferMemory(dev, b.buf, b.mem, 0));
  CK(vkMapMemory(dev, b.mem, 0, size, 0, &b.ptr));
  return b;
}

int main(int argc, char **argv) {
  const char *spvPath = argc > 1 ? argv[1] : "../build/kernel.spv";
  const char *goldPath = argc > 2 ? argv[2] : "../build/golden.csv";

  // golden: seed,index (seeds are 0..N-1 in order)
  uint32_t expected[N];
  FILE *gf = fopen(goldPath, "r"); if (!gf) { perror("golden"); return 2; }
  char line[64]; fgets(line, sizeof line, gf); // header
  for (uint32_t i = 0; i < N; i++) { unsigned s, ix; if (fscanf(gf, "%u,%u\n", &s, &ix) != 2) { fprintf(stderr, "golden short at %u\n", i); return 2; } expected[s] = ix; }
  fclose(gf);

  // spv
  FILE *sf = fopen(spvPath, "rb"); if (!sf) { perror("spv"); return 2; }
  fseek(sf, 0, SEEK_END); long spvLen = ftell(sf); fseek(sf, 0, SEEK_SET);
  uint32_t *spv = malloc(spvLen); if (fread(spv, 1, spvLen, sf) != (size_t)spvLen) return 2; fclose(sf);

  CK(volkInitialize());
  VkApplicationInfo app = { .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO, .apiVersion = VK_API_VERSION_1_1 };
  VkInstanceCreateInfo ici = { .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, .pApplicationInfo = &app };
  VkInstance inst; CK(vkCreateInstance(&ici, NULL, &inst));
  volkLoadInstance(inst);

  uint32_t nd = 0; CK(vkEnumeratePhysicalDevices(inst, &nd, NULL));
  VkPhysicalDevice *devs = malloc(nd * sizeof *devs); CK(vkEnumeratePhysicalDevices(inst, &nd, devs));
  phys = devs[0]; char chosen[256] = "";
  for (uint32_t i = 0; i < nd; i++) { VkPhysicalDeviceProperties p; vkGetPhysicalDeviceProperties(devs[i], &p);
    if (i == 0) snprintf(chosen, sizeof chosen, "%s", p.deviceName);
    if (strstr(p.deviceName, "llvmpipe")) { phys = devs[i]; snprintf(chosen, sizeof chosen, "%s", p.deviceName); break; } }
  printf("device: %s\n", chosen);

  uint32_t nq = 0; vkGetPhysicalDeviceQueueFamilyProperties(phys, &nq, NULL);
  VkQueueFamilyProperties *qf = malloc(nq * sizeof *qf); vkGetPhysicalDeviceQueueFamilyProperties(phys, &nq, qf);
  uint32_t qfi = ~0u; for (uint32_t i = 0; i < nq; i++) if (qf[i].queueFlags & VK_QUEUE_COMPUTE_BIT) { qfi = i; break; }
  if (qfi == ~0u) { fprintf(stderr, "no compute queue\n"); return 2; }

  float prio = 1.0f;
  VkDeviceQueueCreateInfo qci = { .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO, .queueFamilyIndex = qfi, .queueCount = 1, .pQueuePriorities = &prio };
  VkDeviceCreateInfo dci = { .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO, .queueCreateInfoCount = 1, .pQueueCreateInfos = &qci };
  CK(vkCreateDevice(phys, &dci, NULL, &dev));
  volkLoadDevice(dev);
  VkQueue queue; vkGetDeviceQueue(dev, qfi, 0, &queue);

  Buf seeds = mkBuf(N * 4), cumw = mkBuf(3 * 4), out = mkBuf(N * 4);
  for (uint32_t i = 0; i < N; i++) ((uint32_t *)seeds.ptr)[i] = i;
  uint32_t cw[3] = { 50, 80, 100 }; memcpy(cumw.ptr, cw, sizeof cw);
  memset(out.ptr, 0, N * 4);

  VkDescriptorSetLayoutBinding binds[3];
  for (int i = 0; i < 3; i++) binds[i] = (VkDescriptorSetLayoutBinding){ .binding = i, .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = 1, .stageFlags = VK_SHADER_STAGE_COMPUTE_BIT };
  VkDescriptorSetLayoutCreateInfo dl = { .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO, .bindingCount = 3, .pBindings = binds };
  VkDescriptorSetLayout dsl; CK(vkCreateDescriptorSetLayout(dev, &dl, NULL, &dsl));
  VkPipelineLayoutCreateInfo pl = { .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO, .setLayoutCount = 1, .pSetLayouts = &dsl };
  VkPipelineLayout pipeLayout; CK(vkCreatePipelineLayout(dev, &pl, NULL, &pipeLayout));

  VkShaderModuleCreateInfo smi = { .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, .codeSize = spvLen, .pCode = spv };
  VkShaderModule mod; CK(vkCreateShaderModule(dev, &smi, NULL, &mod));
  VkComputePipelineCreateInfo cpi = { .sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
    .stage = { .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_COMPUTE_BIT, .module = mod, .pName = "main" },
    .layout = pipeLayout };
  VkPipeline pipe; CK(vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &cpi, NULL, &pipe));

  VkDescriptorPoolSize ps = { .type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = 3 };
  VkDescriptorPoolCreateInfo dpi = { .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO, .maxSets = 1, .poolSizeCount = 1, .pPoolSizes = &ps };
  VkDescriptorPool pool; CK(vkCreateDescriptorPool(dev, &dpi, NULL, &pool));
  VkDescriptorSetAllocateInfo dsa = { .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO, .descriptorPool = pool, .descriptorSetCount = 1, .pSetLayouts = &dsl };
  VkDescriptorSet set; CK(vkAllocateDescriptorSets(dev, &dsa, &set));

  VkBuffer all[3] = { seeds.buf, cumw.buf, out.buf };
  VkDescriptorBufferInfo dbi[3]; VkWriteDescriptorSet w[3];
  for (int i = 0; i < 3; i++) {
    dbi[i] = (VkDescriptorBufferInfo){ .buffer = all[i], .offset = 0, .range = VK_WHOLE_SIZE };
    w[i] = (VkWriteDescriptorSet){ .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, .dstSet = set, .dstBinding = i, .descriptorCount = 1, .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .pBufferInfo = &dbi[i] };
  }
  vkUpdateDescriptorSets(dev, 3, w, 0, NULL);

  VkCommandPoolCreateInfo cpci = { .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, .queueFamilyIndex = qfi };
  VkCommandPool cmdPool; CK(vkCreateCommandPool(dev, &cpci, NULL, &cmdPool));
  VkCommandBufferAllocateInfo cbi = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, .commandPool = cmdPool, .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY, .commandBufferCount = 1 };
  VkCommandBuffer cmd; CK(vkAllocateCommandBuffers(dev, &cbi, &cmd));
  VkCommandBufferBeginInfo bbi = { .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT };
  CK(vkBeginCommandBuffer(cmd, &bbi));
  vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pipe);
  vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pipeLayout, 0, 1, &set, 0, NULL);
  vkCmdDispatch(cmd, N / WORKGROUP, 1, 1);
  CK(vkEndCommandBuffer(cmd));
  VkSubmitInfo si = { .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO, .commandBufferCount = 1, .pCommandBuffers = &cmd };
  CK(vkQueueSubmit(queue, 1, &si, VK_NULL_HANDLE));
  CK(vkQueueWaitIdle(queue));

  uint32_t *res = (uint32_t *)out.ptr; uint32_t mismatch = 0, firstBad = ~0u;
  for (uint32_t i = 0; i < N; i++) if (res[i] != expected[i]) { if (firstBad == ~0u) firstBad = i; mismatch++; }
  printf("checked %u seeds against golden vectors\n", N);
  if (mismatch == 0) { printf("PARITY PASS: SPIR-V kernel matches the Lean spec on all %u seeds\n", N); return 0; }
  printf("PARITY FAIL: %u mismatches; first at seed %u (spv=%u expected=%u)\n", mismatch, firstBad, res[firstBad], expected[firstBad]);
  return 1;
}
