// GPU r128 parity: dispatch the r128 mul SPIR-V kernel on Vulkan (via volk) and
// check every result against the host r128.c (the oracle). Same algorithm on
// both sides -> bit-exact.
#define R128_IMPLEMENTATION
#define R128_STDC_ONLY
#include "r128.h"
#include "volk.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define COUNT 4096u           // r128 values
#define WG 64u
#define CK(x) do { VkResult _r=(x); if(_r){fprintf(stderr,"VK %d @ %s:%d\n",_r,__FILE__,__LINE__);exit(2);} } while(0)

static VkPhysicalDevice phys; static VkDevice dev;
static uint32_t memType(uint32_t bits, VkMemoryPropertyFlags w){
  VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(phys,&mp);
  for(uint32_t i=0;i<mp.memoryTypeCount;i++) if((bits&(1u<<i))&&(mp.memoryTypes[i].propertyFlags&w)==w) return i;
  exit(2);
}
typedef struct { VkBuffer buf; VkDeviceMemory mem; void*ptr; } Buf;
static Buf mkBuf(VkDeviceSize size){
  Buf b; VkBufferCreateInfo bi={.sType=VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,.size=size,
    .usage=VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,.sharingMode=VK_SHARING_MODE_EXCLUSIVE};
  CK(vkCreateBuffer(dev,&bi,0,&b.buf));
  VkMemoryRequirements rq; vkGetBufferMemoryRequirements(dev,b.buf,&rq);
  VkMemoryAllocateInfo ai={.sType=VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,.allocationSize=rq.size,
    .memoryTypeIndex=memType(rq.memoryTypeBits,VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)};
  CK(vkAllocateMemory(dev,&ai,0,&b.mem)); CK(vkBindBufferMemory(dev,b.buf,b.mem,0));
  CK(vkMapMemory(dev,b.mem,0,size,0,&b.ptr)); return b;
}
static unsigned long long sm(unsigned long long*s){ unsigned long long z=(*s+=0x9E3779B97F4A7C15ULL);
  z=(z^(z>>30))*0xBF58476D1CE4E5B9ULL; z=(z^(z>>27))*0x94D049BB133111EBULL; return z^(z>>31); }

int main(int argc,char**argv){
  const char*spv = argc>1?argv[1]:"r128_mul.spv";
  FILE*sf=fopen(spv,"rb"); if(!sf){perror("spv");return 2;}
  fseek(sf,0,SEEK_END); long n=ftell(sf); fseek(sf,0,SEEK_SET);
  uint32_t*code=malloc(n); if(fread(code,1,n,sf)!=(size_t)n)return 2; fclose(sf);

  // inputs + CPU oracle (host r128.c)
  uint32_t*A=malloc(COUNT*4*4),*B=malloc(COUNT*4*4),*EXP=malloc(COUNT*4*4);
  unsigned long long st=12345;
  for(uint32_t i=0;i<COUNT;i++){
    R128 a,b,r; a.lo=sm(&st);a.hi=sm(&st);b.lo=sm(&st);b.hi=sm(&st);
    r128Mul(&r,&a,&b);
    A[i*4+0]=(uint32_t)a.lo;A[i*4+1]=(uint32_t)(a.lo>>32);A[i*4+2]=(uint32_t)a.hi;A[i*4+3]=(uint32_t)(a.hi>>32);
    B[i*4+0]=(uint32_t)b.lo;B[i*4+1]=(uint32_t)(b.lo>>32);B[i*4+2]=(uint32_t)b.hi;B[i*4+3]=(uint32_t)(b.hi>>32);
    EXP[i*4+0]=(uint32_t)r.lo;EXP[i*4+1]=(uint32_t)(r.lo>>32);EXP[i*4+2]=(uint32_t)r.hi;EXP[i*4+3]=(uint32_t)(r.hi>>32);
  }

  CK(volkInitialize());
  VkApplicationInfo app={.sType=VK_STRUCTURE_TYPE_APPLICATION_INFO,.apiVersion=VK_API_VERSION_1_1};
  VkInstanceCreateInfo ici={.sType=VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,.pApplicationInfo=&app};
  VkInstance inst; CK(vkCreateInstance(&ici,0,&inst)); volkLoadInstance(inst);
  uint32_t nd=0; CK(vkEnumeratePhysicalDevices(inst,&nd,0)); VkPhysicalDevice*ds=malloc(nd*sizeof*ds);
  CK(vkEnumeratePhysicalDevices(inst,&nd,ds)); phys=ds[0]; char nm[256]="";
  for(uint32_t i=0;i<nd;i++){VkPhysicalDeviceProperties p;vkGetPhysicalDeviceProperties(ds[i],&p);
    if(i==0)snprintf(nm,256,"%s",p.deviceName);
    if(strstr(p.deviceName,"llvmpipe")){phys=ds[i];snprintf(nm,256,"%s",p.deviceName);break;}}
  printf("device: %s\n",nm);
  uint32_t nq=0; vkGetPhysicalDeviceQueueFamilyProperties(phys,&nq,0); VkQueueFamilyProperties*qf=malloc(nq*sizeof*qf);
  vkGetPhysicalDeviceQueueFamilyProperties(phys,&nq,qf); uint32_t qfi=~0u;
  for(uint32_t i=0;i<nq;i++) if(qf[i].queueFlags&VK_QUEUE_COMPUTE_BIT){qfi=i;break;}
  float pr=1; VkDeviceQueueCreateInfo qci={.sType=VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,.queueFamilyIndex=qfi,.queueCount=1,.pQueuePriorities=&pr};
  VkDeviceCreateInfo dci={.sType=VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,.queueCreateInfoCount=1,.pQueueCreateInfos=&qci};
  CK(vkCreateDevice(phys,&dci,0,&dev)); volkLoadDevice(dev);
  VkQueue queue; vkGetDeviceQueue(dev,qfi,0,&queue);

  Buf ba=mkBuf(COUNT*4*4), bb=mkBuf(COUNT*4*4), bo=mkBuf(COUNT*4*4);
  memcpy(ba.ptr,A,COUNT*4*4); memcpy(bb.ptr,B,COUNT*4*4); memset(bo.ptr,0,COUNT*4*4);

  VkDescriptorSetLayoutBinding bd[3];
  for(int i=0;i<3;i++) bd[i]=(VkDescriptorSetLayoutBinding){.binding=i,.descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,.descriptorCount=1,.stageFlags=VK_SHADER_STAGE_COMPUTE_BIT};
  VkDescriptorSetLayoutCreateInfo dl={.sType=VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,.bindingCount=3,.pBindings=bd};
  VkDescriptorSetLayout dsl; CK(vkCreateDescriptorSetLayout(dev,&dl,0,&dsl));
  VkPipelineLayoutCreateInfo pli={.sType=VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,.setLayoutCount=1,.pSetLayouts=&dsl};
  VkPipelineLayout plo; CK(vkCreatePipelineLayout(dev,&pli,0,&plo));
  VkShaderModuleCreateInfo smi={.sType=VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,.codeSize=n,.pCode=code};
  VkShaderModule mod; CK(vkCreateShaderModule(dev,&smi,0,&mod));
  VkComputePipelineCreateInfo cpi={.sType=VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
    .stage={.sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,.stage=VK_SHADER_STAGE_COMPUTE_BIT,.module=mod,.pName="main"},.layout=plo};
  VkPipeline pipe; CK(vkCreateComputePipelines(dev,0,1,&cpi,0,&pipe));
  VkDescriptorPoolSize ps={.type=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,.descriptorCount=3};
  VkDescriptorPoolCreateInfo dpi={.sType=VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,.maxSets=1,.poolSizeCount=1,.pPoolSizes=&ps};
  VkDescriptorPool pool; CK(vkCreateDescriptorPool(dev,&dpi,0,&pool));
  VkDescriptorSetAllocateInfo dsa={.sType=VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,.descriptorPool=pool,.descriptorSetCount=1,.pSetLayouts=&dsl};
  VkDescriptorSet set; CK(vkAllocateDescriptorSets(dev,&dsa,&set));
  VkBuffer all[3]={ba.buf,bb.buf,bo.buf}; VkDescriptorBufferInfo dbi[3]; VkWriteDescriptorSet w[3];
  for(int i=0;i<3;i++){dbi[i]=(VkDescriptorBufferInfo){.buffer=all[i],.range=VK_WHOLE_SIZE};
    w[i]=(VkWriteDescriptorSet){.sType=VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,.dstSet=set,.dstBinding=i,.descriptorCount=1,.descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,.pBufferInfo=&dbi[i]};}
  vkUpdateDescriptorSets(dev,3,w,0,0);
  VkCommandPoolCreateInfo cpci={.sType=VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,.queueFamilyIndex=qfi};
  VkCommandPool cp; CK(vkCreateCommandPool(dev,&cpci,0,&cp));
  VkCommandBufferAllocateInfo cbi={.sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,.commandPool=cp,.level=VK_COMMAND_BUFFER_LEVEL_PRIMARY,.commandBufferCount=1};
  VkCommandBuffer cmd; CK(vkAllocateCommandBuffers(dev,&cbi,&cmd));
  VkCommandBufferBeginInfo bbi={.sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,.flags=VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT};
  CK(vkBeginCommandBuffer(cmd,&bbi));
  vkCmdBindPipeline(cmd,VK_PIPELINE_BIND_POINT_COMPUTE,pipe);
  vkCmdBindDescriptorSets(cmd,VK_PIPELINE_BIND_POINT_COMPUTE,plo,0,1,&set,0,0);
  vkCmdDispatch(cmd,COUNT/WG,1,1);
  CK(vkEndCommandBuffer(cmd));
  VkSubmitInfo si={.sType=VK_STRUCTURE_TYPE_SUBMIT_INFO,.commandBufferCount=1,.pCommandBuffers=&cmd};
  CK(vkQueueSubmit(queue,1,&si,0)); CK(vkQueueWaitIdle(queue));

  uint32_t*OUT=(uint32_t*)bo.ptr; long bad=0,first=-1;
  for(uint32_t i=0;i<COUNT*4;i++) if(OUT[i]!=EXP[i]){ if(first<0)first=i/4; bad++; }
  printf("checked %u r128 multiplies against host r128.c\n",COUNT);
  if(!bad){ printf("R128 GPU PARITY PASS: SPIR-V kernel == host r128 on all %u multiplies\n",COUNT); return 0; }
  printf("R128 GPU PARITY FAIL: %ld limb mismatches, first value index %ld\n",bad,first); return 1;
}
