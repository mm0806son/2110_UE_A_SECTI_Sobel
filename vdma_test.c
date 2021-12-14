/*
 * vdma_test.c
 *
 *  Created on: 18 oct. 2021
 *      Author: s18weith
 */

#include "xparameters.h"
#include "xaxivdma.h"
#include "xscugic.h"
#include "sleep.h"
#include <stdlib.h>
#include "xil_cache.h"
#include "IMT_LOGO_100x100.h"

#define HSize 640
#define VSize 480

#define FrameSize HSize *VSize * 3

#define imgHSize 100
#define imgVSize 100
#define imageSize imgHSize *imgVSize

char imageData[imageSize];

// for dma/image processing
#include "xil_types.h"

static XScuGic Intc;
char Buffer[FrameSize];

static int SetupIntrSystem(XAxiVdma *AxiVdmaPtr, u16 ReadIntrId);

int drawImage(u32 displayHSize, u32 displayVSize, u32 imageHSize, u32 imageVSize, u32 hOffset, u32 vOffset, int numColors, char *imagePointer, char *videoFramePointer);

int main()
{

	int status;
	int Index;
	u32 Addr;
	XAxiVdma myVDMA;
	XAxiVdma_Config *config = XAxiVdma_LookupConfig(XPAR_AXI_VDMA_DEVICE_ID); //TODO Address here
	XAxiVdma_DmaSetup ReadCfg;
	status = XAxiVdma_CfgInitialize(&myVDMA, config, config->BaseAddress);
	if (status != XST_SUCCESS)
	{
		xil_printf("DMA Initialization failed");
	}
	ReadCfg.VertSizeInput = VSize;
	ReadCfg.HoriSizeInput = HSize * 3;
	ReadCfg.Stride = HSize * 3;
	ReadCfg.FrameDelay = 0;
	ReadCfg.EnableCircularBuf = 1;
	ReadCfg.EnableSync = 1;
	ReadCfg.PointNum = 0;
	ReadCfg.EnableFrameCounter = 0;
	ReadCfg.FixedFrameStoreAddr = 0;
	status = XAxiVdma_DmaConfig(&myVDMA, XAXIVDMA_READ, &ReadCfg);
	if (status != XST_SUCCESS)
	{
		xil_printf("Write channel config failed %d\r\n", status);
		return status;
	}

	Addr = (u32) & (Buffer[0]);

	for (Index = 0; Index < myVDMA.MaxNumFrames; Index++)
	{
		ReadCfg.FrameStoreStartAddr[Index] = Addr;
		Addr += FrameSize;
	}

	status = XAxiVdma_DmaSetBufferAddr(&myVDMA, XAXIVDMA_READ, ReadCfg.FrameStoreStartAddr);
	if (status != XST_SUCCESS)
	{
		xil_printf("Read channel config failed %d\r\n", status);
		return XST_FAILURE;
	}

	XAxiVdma_IntrEnable(&myVDMA, XAXIVDMA_IXR_COMPLETION_MASK, XAXIVDMA_READ);
	SetupIntrSystem(&myVDMA, XPAR_FABRIC_AXI_VDMA_MM2S_INTROUT_INTR); //TODO Address here

	drawImage(HSize, VSize, imgHSize, imgVSize, (HSize - imgHSize) / 2, (VSize - imgVSize) / 2, 1, imageData, Buffer);
	Xil_DCacheFlush();

	status = XAxiVdma_DmaStart(&myVDMA, XAXIVDMA_READ);
	if (status != XST_SUCCESS)
	{
		if (status != XST_VDMA_MISMATCH_ERROR)
		{
			xil_printf("DMA Mismatch Error\r\n");
		}
		return XST_FAILURE;
	}

	while (1)
	{
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

static int SetupIntrSystem(XAxiVdma *AxiVdmaPtr, u16 ReadIntrId)
{
	int Status;
	XScuGic *IntcInstancePtr = &Intc;

	XScuGic_Config *IntcConfig;
	IntcConfig = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
	Status = XScuGic_CfgInitialize(IntcInstancePtr, IntcConfig, IntcConfig->CpuBaseAddress);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Interrupt controller initialization failed..");
		return -1;
	}

	Status = XScuGic_Connect(IntcInstancePtr, ReadIntrId, (Xil_InterruptHandler)XAxiVdma_ReadIntrHandler, (void *)AxiVdmaPtr);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Failed read channel connect intc %d\r\n", Status);
		return XST_FAILURE;
	}

	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, (void *)IntcInstancePtr);
	Xil_ExceptionEnable();

	XAxiVdma_SetCallBack(AxiVdmaPtr, XAXIVDMA_HANDLER_GENERAL, ReadCallBack, (void *)AxiVdmaPtr, XAXIVDMA_READ);
	XAxiVdma_SetCallBack(AxiVdmaPtr, XAXIVDMA_HANDLER_ERROR, ReadErrorCallBack, (void *)AxiVdmaPtr, XAXIVDMA_READ);

	return XST_SUCCESS;
}

static int SetupVideoIntrSystem(XAxiVdma *AxiVdmaPtr, u16 ReadIntrId, XScuGic *Intc)
{
	int Status;
	XScuGic *IntcInstancePtr = Intc;

	Status = XScuGic_Connect(IntcInstancePtr, ReadIntrId, (Xil_InterruptHandler)XAxiVdma_ReadIntrHandler, (void *)AxiVdmaPtr);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Failed read channel connect intc %d\r\n", Status);
		return XST_FAILURE;
	}

	XScuGic_Enable(IntcInstancePtr, ReadIntrId);

	XAxiVdma_SetCallBack(AxiVdmaPtr, XAXIVDMA_HANDLER_GENERAL, ReadCallBack, (void *)AxiVdmaPtr, XAXIVDMA_READ);

	XAxiVdma_SetCallBack(AxiVdmaPtr, XAXIVDMA_HANDLER_ERROR, ReadErrorCallBack, (void *)AxiVdmaPtr, XAXIVDMA_READ);

	return XST_SUCCESS;
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
int drawImage(u32 displayHSize, u32 displayVSize, u32 imageHSize, u32 imageVSize, u32 hOffset, u32 vOffset, int numColors, char *imagePointer, char *videoFramePointer)
{
	Xil_DCacheInvalidateRange((u32)imagePointer, (imageHSize * imageVSize));
	for (int i = 0; i < displayVSize; i++)
	{
		for (int j = 0; j < displayHSize; j++)
		{
			if (i < vOffset || i >= vOffset + imageVSize)
			{
				videoFramePointer[(i * displayHSize * 3) + (j * 3)] = 0x00;
				videoFramePointer[(i * displayHSize * 3) + (j * 3) + 1] = 0x00;
				videoFramePointer[(i * displayHSize * 3) + (j * 3) + 2] = 0x00;
			}
			else if (j < hOffset || j >= hOffset + imageHSize)
			{
				videoFramePointer[(i * displayHSize * 3) + (j * 3)] = 0x00;
				videoFramePointer[(i * displayHSize * 3) + (j * 3) + 1] = 0x00;
				videoFramePointer[(i * displayHSize * 3) + (j * 3) + 2] = 0x00;
			}
			else
			{
				if (numColors == 1)
				{
					videoFramePointer[(i * displayHSize * 3) + j * 3] = *imagePointer / 16;
					videoFramePointer[(i * displayHSize * 3) + (j * 3) + 1] = *imagePointer / 16;
					videoFramePointer[(i * displayHSize * 3) + (j * 3) + 2] = *imagePointer / 16;
					imagePointer++;
				}
				else if (numColors == 3)
				{
					videoFramePointer[(i * displayHSize * 3) + j * 3] = *imagePointer / 16;
					videoFramePointer[(i * displayHSize * 3) + (j * 3) + 1] = *(imagePointer++) / 16;
					videoFramePointer[(i * displayHSize * 3) + (j * 3) + 2] = *(imagePointer++) / 16;
					imagePointer++;
				}
			}
		}
	}
	Xil_DCacheFlush();
	return 0;
}
