# ImageBuffer

## ImageBuffer function

Depending on the ability of the LineBuffer to read and write to a line of pixels, ImageBuffer allows the reading and writing of the entire image by switching the LineBuffers correctly.

In this example, we use four Linebuffers to implement the image read and write function.

## Main functions

### Ideal location:

- increment_write_en_s:

When a line is full and new data is entered from outside, the written linebuffer is modified by cyclically shifting all data in write_en_s one bit to the left.
This is done by taking the value of write_en_s(FILTER_SIZE) from write_en_s and placing it in write_en_s(0), shifting the rest of the value one bit to the left.

- increment_count_write:

Record how many lines of data have been read so far.

- proc_write:

Activates the specific Linebuffer used.
To avoid overwriting the part being read by writing too fast.
The difference between the number of lines written and the number of lines read must not exceed FILTER_SIZE lines, except for the first few lines. If the above conditions are met and new data is entered, activate the Linebuffer according to the parameters changed by increment_write_in_s

**The above is how the write section works, the read section should have a similar structure, with only the difference of conditionals and partial assignments, and should use the following three functions**

- increment_write_en_s:
- increment_count_write
- proc_write:

At this point, the Imagebuffer can be adapted to different filter area sizes by changing only one FILTER_SIZE value, without any other code modification

### Real situation

However, due to time constraints, this part of the code has not been fully optimized and the read function is currently implemented by the following functions.

- increment_count_write:

Record how many lines of data have been written so far.

- increment_LineBuffer_rd_ptr:

To prevent reading from being much faster than writing and resulting in read failures, we limit the number of lines read to a minimum of FILTER_SIZE lines slower than the number of lines written.
And here we configure the LineBuffer_rd_ptr to cycle from 0 to FILTER_SIZE when reading from the edge.

- read_not_en_ptr:

In fact, when LineBuffer_rd_ptr is greater than zero, the non-functional Linebuffer is LineBuffer_rd_ptr minus one.

- proc_read:

Activates the specific Linebuffer used.
However, unlike before, the writing section uses only one Linebuffer, while the reading section uses three.
When the edge of an image line is read, the next Linebuffer usage is determined by considering all cases, based on the current Linebuffer usage.