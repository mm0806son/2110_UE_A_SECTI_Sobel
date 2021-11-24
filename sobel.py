import numpy as np
import cv2
import argparse
import matplotlib.pyplot as plt


def sobel(image, num_rows, num_columns, threshold):
    out_image = np.zeros((num_rows, num_columns))
    pixels = np.zeros(9)
    for row in range(0, num_rows - 3):
        for column in range(0, num_columns - 3):
            pixels[0] = image[row][column]
            pixels[1] = image[row + 1][column]
            pixels[2] = image[row + 2][column]
            pixels[3] = image[row][column + 1]
            pixels[4] = image[row + 1][column + 1]
            pixels[5] = image[row + 2][column + 1]
            pixels[6] = image[row][column + 2]
            pixels[7] = image[row + 1][column + 2]
            pixels[8] = image[row + 2][column + 2]

            Gh = -pixels[0] - 2 * pixels[1] - pixels[2] + pixels[6] + 2 * pixels[7] + pixels[8]  # S_x
            Gv = pixels[0] + 2 * pixels[3] + pixels[6] - pixels[2] - 2 * pixels[5] - pixels[7]  # S_y

            gradient = abs(Gh) + abs(Gv)

            if gradient > threshold:
                out_image[row + 1][column + 1] = 1
            else:
                out_image[row + 1][column + 1] = 0
    return out_image


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--image", required=True, help="Path to the image")
    args = vars(ap.parse_args())

    image = cv2.imread(args["image"])
    image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # plt.imshow(image, cmap='gray')
    # plt.title("Original")
    # plt.show()

    num_rows = len(image)
    num_columns = len(image[0])

    f = open(args["image"].strip(".jpeg") + ".csv", "w")
    for row in range(0, num_rows):
        out_string = ""
        for col in range(0, num_columns):
            out_string = out_string + str(image[num_rows - 1 - row][num_columns - 1 - col]) + " "
        f.write(out_string + "\n")
    f.close()

    threshold = 255

    out_image = sobel(image, num_rows, num_columns, threshold)
    f = open(args["image"].strip(".jpeg") + "_reference.csv", "w")
    for row in range(0, num_rows):
        out_string = ""
        for col in range(0, num_columns):
            out_string = out_string + str(out_image[num_rows - 1 - row][num_columns - 1 - col]) + " "
        f.write(out_string + "\n")
    f.close()

    # plt.imshow(out_image, cmap='gray')
    # plt.title("Filtered")
    # plt.show()
