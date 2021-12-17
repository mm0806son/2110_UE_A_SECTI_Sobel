# 2110_UE_A_SECTI_Sobel

Project of course UE_A_SECTI at IMT Atlantique.

GitHub repository: https://github.com/mm0806son/2110_UE_A_SECTI_Sobel

**Made by:**

- Zijie NING @[mm0806son](https://github.com/mm0806son)
- Guoxiong SUN @[GuoxiongSUN](https://github.com/GuoxiongSUN)

**Context and Goals**

The objective of this course is to implement a heterogeneous image processing system. It builds on the competences acquired in the courses Méthodologies de conception - de l’algorithme à la puce (PUCE) and Systèmes embarqués - interaction matériel-logiciel (SEIML) and apply them in a project context. The targeted hardware platform for the project is the ZedBoard board which includes a Xilinx Zynq-7020 SoC with two Cortex-A9 ARM cores embedded on the FPGA fabric.

**Main features**

- Generic code, compatible with any `FILTER_SIZE`, `PIXEL_BW`, `IMAGE_WIDTH` and `IMAGE_HEIGHT`.

- We defined following architecture:

  - `Soble_coproc` (for communication with peripheral)

    - `ImageBuffer` (controller of the linebuffers)

      Depending on the ability of the LineBuffer to read and write to a line of pixels, ImageBuffer allows the reading and writing of the entire image by switching the LineBuffers correctly.

      - `LineBuffer` (read and write pixels of one line)

        In this example (`FILTER_SIZE = 3`), we use 4 Linebuffers to implement the image read and write function.

**Block design**

<img src="https://raw.githubusercontent.com/mm0806son/2110_UE_A_SECTI_Sobel/main/readme/Block%20Design.png?token=ART4NBPK5W44V2PU2Z2VLJLBXUGPI" style="zoom: 25%;" />

**Output wave of testbench**

<img src="https://raw.githubusercontent.com/mm0806son/2110_UE_A_SECTI_Sobel/main/readme/wave.png?token=ART4NBKN6B5UIQESGZTMENLBXUGU6" alt="Output wave" style="zoom:25%;" />

