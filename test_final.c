/*
* test_final.c
 *
 *  Created on: 14 dec. 2021
 *      Author: s18weith
 */

#include "xparameters.h"
#include "xaxivdma.h"
#include "xscugic.h"
#include "sleep.h"
#include <stdlib.h>
#include "xil_cache.h"
#include "xil_types.h"
#include "xaxidma.h"
#include "IMT_LOGO_100x100.h"

#define HSize 640
#define VSize 480
#define FrameSize HSize*VSize*3

#define imgHSize 100
#define imgVSize 100
#define imageSize imgHSize*imgVSize

char imageData[imageSize];

typedef struct{
	char *imageDataPointer;
	char *filteredImageDataPointer;
	XAxiDma *DmaCtrlPointer;
	XScuGic *IntrCtrlPointer;
	u32 imageHSize;
	u32 imageVSize;
	u32 done;
}imgProcess;


char Buffer[FrameSize];

static int SetupVideoIntrSystem(XAxiVdma *AxiVdmaPtr, u16 ReadIntrId, XScuGic *Intc);
int initIntrController(XScuGic *IntcInstancePtr);

int initImgProcessSystem(imgProcess *imgProcessInstance, u32 axiDmaBaseAddress,XScuGic *Intc);
int startImageProcessing(imgProcess *imgProcessInstance);
int drawImage(u32 displayHSize,u32 displayVSize,u32 imageHSize,u32 imageVSize,u32 hOffset, u32 vOffset,int numColors,char *imagePointer,char *videoFramePointer);

int main(){
	xil_printf("Start 000\n");
	XScuGic Intc;
	initIntrController(&Intc);
	xil_printf("Start 001\n");


	imgProcess myImgProcess;
	char *filteredImage;
	filteredImage = malloc(sizeof(char)*(imgHSize*imgVSize));
	myImgProcess.imageDataPointer = imageData;
	myImgProcess.imageHSize = imgHSize;
	myImgProcess.imageVSize = imgVSize;
	myImgProcess.filteredImageDataPointer = filteredImage;
	xil_printf(initImgProcessSystem(&myImgProcess, (u32)XPAR_AXI_DMA_0_BASEADDR, &Intc));//TODO Address here
	xil_printf(startImageProcessing(&myImgProcess));
	xil_printf("myImgProcess.done");

	int status;
	int Index;
	u32 Addr;
	XAxiVdma myVDMA;
	XAxiVdma_Config *config = XAxiVdma_LookupConfig(XPAR_AXI_VDMA_DEVICE_ID);//TODO Address here
	XAxiVdma_DmaSetup ReadCfg;
	status = XAxiVdma_CfgInitialize(&myVDMA, config, config->BaseAddress);
	if(status != XST_SUCCESS) {
		xil_printf("DMA Initialization failed");
	}
	ReadCfg.VertSizeInput = VSize;
	ReadCfg.HoriSizeInput = HSize*3;
	ReadCfg.Stride = HSize*3;
	ReadCfg.FrameDelay = 0;
	ReadCfg.EnableCircularBuf = 1;
	ReadCfg.EnableSync = 1;
	ReadCfg.PointNum = 0;
	ReadCfg.EnableFrameCounter = 0;
	ReadCfg.FixedFrameStoreAddr = 0;
	status = XAxiVdma_DmaConfig(&myVDMA, XAXIVDMA_READ, &ReadCfg);
	if(status != XST_SUCCESS) {
		xil_printf("Write channel config failed %d\r\n",status);
		return status;
	}

	Addr = (u32)&(Buffer[0]);

	for(Index = 0; Index < myVDMA.MaxNumFrames; Index++) {
		ReadCfg.FrameStoreStartAddr[Index] = Addr;
		Addr += FrameSize;
	}

	status = XAxiVdma_DmaSetBufferAddr(&myVDMA, XAXIVDMA_READ, ReadCfg.FrameStoreStartAddr);
	if (status != XST_SUCCESS) {
		xil_printf("Read channel config failed %d\r\n",status);
		return XST_FAILURE;
	}

	XAxiVdma_IntrEnable(&myVDMA, XAXIVDMA_IXR_COMPLETION_MASK, XAXIVDMA_READ);
	SetupVideoIntrSystem(&myVDMA, XPAR_FABRIC_AXI_VDMA_MM2S_INTROUT_INTR,&Intc);//TODO Address here

    while(!myImgProcess.done){
    }

	status = XAxiVdma_DmaStart(&myVDMA,XAXIVDMA_READ);
	if (status != XST_SUCCESS) {
		if (status != XST_VDMA_MISMATCH_ERROR) {
			xil_printf("DMA Mismatch Error\r\n");
		}
		return XST_FAILURE;
	}

	xil_printf("Finish\n");


	while(1){
		drawImage(HSize,VSize,imgHSize,imgVSize,(HSize-imgHSize)/2,(VSize-imgVSize)/2,1,filteredImage,Buffer);//filteredImage
		sleep(1);
		drawImage(HSize,VSize,imgHSize,imgVSize,(HSize-imgHSize)/2,(VSize-imgVSize)/2,1,filteredImage,Buffer);//imageData
		sleep(1);
	}

}

/*****************************************************************************/
 /* Call back function for read channel
******************************************************************************/

static void ReadCallBack(void *CallbackRef, u32 Mask)
{
        /* User can add his code in this call back function */
        //xil_printf("Read Call back function is called\r\n");
}

/*****************************************************************************/
/*
 * The user can put his code that should get executed when this
 * call back happens.
 *
*
******************************************************************************/
static void ReadErrorCallBack(void *CallbackRef, u32 Mask)
{
        /* User can add his code in this call back function */
        xil_printf("Read Call back Error function is called\r\n");

}


int initIntrController(XScuGic *IntcInstancePtr){
	int Status;
	XScuGic_Config *IntcConfig;
	IntcConfig = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
	Status =  XScuGic_CfgInitialize(IntcInstancePtr, IntcConfig, IntcConfig->CpuBaseAddress);
	if(Status != XST_SUCCESS){
		xil_printf("Interrupt controller initialization failed..");
		return -1;
	}

	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,(Xil_ExceptionHandler)XScuGic_InterruptHandler,(void *)IntcInstancePtr);
	Xil_ExceptionEnable();

	return XST_SUCCESS;
}

static int SetupVideoIntrSystem(XAxiVdma *AxiVdmaPtr, u16 ReadIntrId, XScuGic *Intc)
{
	int Status;
	XScuGic *IntcInstancePtr = Intc;

	Status = XScuGic_Connect(IntcInstancePtr,ReadIntrId,(Xil_InterruptHandler)XAxiVdma_ReadIntrHandler,(void *)AxiVdmaPtr);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed read channel connect intc %d\r\n", Status);
		return XST_FAILURE;
	}

	XScuGic_Enable(IntcInstancePtr,ReadIntrId);

	XAxiVdma_SetCallBack(AxiVdmaPtr, XAXIVDMA_HANDLER_GENERAL, ReadCallBack, (void *)AxiVdmaPtr, XAXIVDMA_READ);

	XAxiVdma_SetCallBack(AxiVdmaPtr, XAXIVDMA_HANDLER_ERROR, ReadErrorCallBack, (void *)AxiVdmaPtr, XAXIVDMA_READ);

	return XST_SUCCESS;
}

/*****************************************************************************/
/**
 * This function initializes the DMA operation for image processing
 *
 * @param	imgProcessInstance is a pointer to the initialized imgProcess instance
 * 		-  0 DMA initiated successfully
 * 		- -1 DMA initiation failed
 *****************************************************************************/

int startImageProcessing(imgProcess *imgProcessInstance){
	int status;
	//status = XAxiDma_SimpleTransfer(imgProcessInstance->DmaCtrlPointer,(u32)imgProcessInstance->filteredImageDataPointer,(imgProcessInstance->imageHSize)*(imgProcessInstance->imageVSize),XAXIDMA_DEVICE_TO_DMA);
	status = XAxiDma_SimpleTransfer(imgProcessInstance->DmaCtrlPointer,(u32)imgProcessInstance->filteredImageDataPointer,imgHSize*imgVSize,XAXIDMA_DEVICE_TO_DMA);
	if(status != XST_SUCCESS){
		xil_printf("DMA Receive Failed with Status %d\n",status);
		return -1;
	}
	status = XAxiDma_SimpleTransfer(imgProcessInstance->DmaCtrlPointer,(u32)imgProcessInstance->imageDataPointer, 4*imgHSize,XAXIDMA_DMA_TO_DEVICE);
	if(status != XST_SUCCESS){
		xil_printf("DMA Transfer failed with Status %d\n",status);
		return -1;
	}
	return 0;
}

/*****************************************************************************/
/**imgVSize
 * This function is the interrupt service routine for DMA S2MM interrupt
 *
 * @param	CallBackRef is a pointer to the initialized imgProcess instance
 *
 *****************************************************************************/

static void dmaReceiveISR(void *CallBackRef){
	XAxiDma_IntrDisable((XAxiDma *)(((imgProcess*)CallBackRef)->DmaCtrlPointer), XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrAckIrq((XAxiDma *)(((imgProcess*)CallBackRef)->DmaCtrlPointer), XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
	((imgProcess*)CallBackRef)->done=1;
	XAxiDma_IntrEnable((XAxiDma *)(((imgProcess*)CallBackRef)->DmaCtrlPointer), XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
}

/*****************************************************************************/
/**
 * This function checks whether a DMA channel is IDLE
 *
 * @param	baseAddress is the baseAddress of DMA Controller
 * @param   offset is the offset of Status register
 *
 *****************************************************************************/
u32 checkIdle(u32 baseAddress,u32 offset){
	u32 status;
	status = (XAxiDma_ReadReg(baseAddress,offset))&XAXIDMA_IDLE_MASK;
	return status;
}

/*****************************************************************************/
/**
 * This function is the interrupt service routine for the image processing IP
 *
 * @param	CallBackRef is a pointer to the initialized imgProcess instance
 *
 *****************************************************************************/

static void imageProcISR(void *CallBackRef){
	static int i=4;
	int status;
	XScuGic_Disable(((imgProcess*)CallBackRef)->IntrCtrlPointer,XPAR_FABRIC_SOBEL_COPROC_1_INTERRUPT_OUT_INTR);//TODO Address here
	status = checkIdle(XPAR_AXI_DMA_0_BASEADDR,0x4);//TODO Address here
	while(status == 0)
		status = checkIdle(XPAR_AXI_DMA_0_BASEADDR,0x4);//TODO Address here
	if(i<imgVSize+2){
		status = XAxiDma_SimpleTransfer(((imgProcess*)CallBackRef)->DmaCtrlPointer,(u32)(((imgProcess*)CallBackRef)->imageDataPointer)+i*((imgProcess*)CallBackRef)->imageHSize,((imgProcess*)CallBackRef)->imageHSize,XAXIDMA_DMA_TO_DEVICE);
		i++;
	}
	XScuGic_Enable(((imgProcess*)CallBackRef)->IntrCtrlPointer,XPAR_FABRIC_SOBEL_COPROC_1_INTERRUPT_OUT_INTR);//TODO Address here
}


/*****************************************************************************/
/**
 * This function copies the buffer data from image buffer to video buffer
 *
 * @param	displayHSize is Horizontal size of video in pixels
 * @param   displayVSize is Vertical size of video in pixels
 * @param	imageHSize is Horizontal size of image in pixels
 * @param   imageVSize is Vertical size of image in pixels
 * @param   hOffset is horizontal position in the video frame where image should be displayed
 * @param   vOffset is vertical position in the video frame where image should be displayed
 * @param   imagePointer pointer to the image buffer
 * @return
 * 		-  0 if successfully copied
 * 		- -1 if copying failed
 *****************************************************************************/
int drawImage(u32 displayHSize,u32 displayVSize,u32 imageHSize,u32 imageVSize,u32 hOffset, u32 vOffset,int numColors,char *imagePointer,char *videoFramePointer){
	Xil_DCacheInvalidateRange((u32)imagePointer,(imageHSize*imageVSize));
	for(int i=0;i<displayVSize;i++){
		for(int j=0;j<displayHSize;j++){
			if(i<vOffset || i >= vOffset+imageVSize){
				videoFramePointer[(i*displayHSize*3)+(j*3)]   = 0x00;
				videoFramePointer[(i*displayHSize*3)+(j*3)+1] = 0x00;
				videoFramePointer[(i*displayHSize*3)+(j*3)+2] = 0x00;
			}
			else if(j<hOffset || j >= hOffset+imageHSize){
				videoFramePointer[(i*displayHSize*3)+(j*3)]   = 0x00;
				videoFramePointer[(i*displayHSize*3)+(j*3)+1] = 0x00;
				videoFramePointer[(i*displayHSize*3)+(j*3)+2] = 0x00;
			}
			else {
				if(numColors==1){
					videoFramePointer[(i*displayHSize*3)+j*3]     = *imagePointer/16;
					videoFramePointer[(i*displayHSize*3)+(j*3)+1] = *imagePointer/16;
					videoFramePointer[(i*displayHSize*3)+(j*3)+2] = *imagePointer/16;
					imagePointer++;
				}
				else if(numColors==3){
					videoFramePointer[(i*displayHSize*3)+j*3]     = *imagePointer/16;
					videoFramePointer[(i*displayHSize*3)+(j*3)+1] = *(imagePointer++)/16;
					videoFramePointer[(i*displayHSize*3)+(j*3)+2] = *(imagePointer++)/16;
					imagePointer++;
				}
			}
		}
	}
	Xil_DCacheFlush();
	return 0;
}

/*****************************************************************************/
/**
 * This function initializes the DMA Controller and interrupts for Image Processing
 *XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR
 * @param	imgProcess is a pointer to ImageProcess instance
 * @param   axiDmaBaseAddress base address for DMA Controller
 * @param	Intc Pointer to interrupt controller
 * 		-  0 if successfully initialized
 * 		- -1 DMA initialization failed
 * 		- -2 Interrupt setup failed
 *****************************************************************************/


int initImgProcessSystem(imgProcess *imgProcessInstance, u32 axiDmaBaseAddress,XScuGic *Intc){
	int status;
	XAxiDma_Config *myDmaConfig;
	XAxiDma myDma;
	myDmaConfig = XAxiDma_LookupConfigBaseAddr(axiDmaBaseAddress);
	status = XAxiDma_CfgInitialize(&myDma, myDmaConfig);
	if(status != XST_SUCCESS){
		xil_printf("DMA initialization failed with status %d\n",status);
		return -1;
	}
	imgProcessInstance->DmaCtrlPointer = &myDma;
	XAxiDma_IntrEnable(&myDma, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
	XScuGic_SetPriorityTriggerType(Intc,XPAR_FABRIC_SOBEL_COPROC_1_INTERRUPT_OUT_INTR,0xA0,3);//TODO Address here
	status = XScuGic_Connect(Intc,XPAR_FABRIC_SOBEL_COPROC_1_INTERRUPT_OUT_INTR,(Xil_InterruptHandler)imageProcISR,(void *)imgProcessInstance);//TODO Address here

	if(status != XST_SUCCESS){
		xil_printf("Interrupt connection failed");
		return -2;
	}
	XScuGic_Enable(Intc,XPAR_FABRIC_SOBEL_COPROC_1_INTERRUPT_OUT_INTR);//TODO Address here

	XScuGic_SetPriorityTriggerType(Intc,XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR,0xA1,3);//TODO Address here
	status = XScuGic_Connect(Intc,XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR,(Xil_InterruptHandler)dmaReceiveISR,(void *)imgProcessInstance);//TODO Address here
	if(status != XST_SUCCESS){
		xil_printf("Interrupt connection failed");
		return -2;
	}
	XScuGic_Enable(Intc,XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);//TODO Address here

	imgProcessInstance->IntrCtrlPointer=Intc;

	imgProcessInstance->done = 0;
	return 0;
}



