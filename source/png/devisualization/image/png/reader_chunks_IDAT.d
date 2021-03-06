﻿/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 Devisualization (Richard Andrew Cattermole)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
module devisualization.image.png.reader_chunks_IDAT;
import devisualization.image.png.defs;
import devisualization.image.png.chunks;
import devisualization.image;

void handle_IDAT_chunk(PngImage _, ubyte[] chunkData) {
    with(_) {
        ubyte[] pixelData;
        size_t colorSize;

        if (IHDR.compressionMethod == PngIHDRCompresion.DeflateInflate) {
            size_t expectedSize;

            if (IHDR.compressionMethod == PngIHDRCompresion.DeflateInflate) {
                decompressInflateDeflate(_, chunkData,
                                        pixelData, expectedSize, colorSize);
            } else {
                throw new NotAnImageException("Unknown compression method");
            }
        } else {
            throw new NotAnImageException("Invalid image compression method");
        }

        ubyte[] adaptiveOffsets;
        ubyte[][] rawPixelData = grabPixelsRawData(_, pixelData, adaptiveOffsets, colorSize);
        
        if (IHDR.filterMethod == PngIHDRFilter.Adaptive) {
            IDAT.unfiltered_uncompressed_pixels = adaptivePixelGrabber(_, rawPixelData, adaptiveOffsets, colorSize);
        } else {
            throw new NotAnImageException("Invalid image filter method");
        }

        if (IHDR.interlaceMethod == PngIHDRInterlaceMethod.Adam7) {
            // TODO: un Adam7 algo IDAT.unfiltered_uncompressed_pixels
        } else if (IHDR.interlaceMethod == PngIHDRInterlaceMethod.NoInterlace) {
        } else {
            throw new NotAnImageException("Invalid image filter method");
        }

		allMyPixels.length = IDAT.unfiltered_uncompressed_pixels.length;
        foreach(i, pixel; IDAT.unfiltered_uncompressed_pixels) {
            if (pixel.used_color) {
                if (IHDR.bitDepth == PngIHDRBitDepth.BitDepth16) {
					allMyPixels[i] = Color_RGBA(pixel.r, pixel.g, pixel.b, pixel.a);
                } else if (IHDR.bitDepth == PngIHDRBitDepth.BitDepth8) {
					allMyPixels[i] = Color_RGBA(cast(ushort)(pixel.r * ubyteToUshort),
					                              cast(ushort)(pixel.g * ubyteToUshort),
					                              cast(ushort)(pixel.b * ubyteToUshort),
					                              cast(ushort)(pixel.a * ubyteToUshort));
				} else {
					// TODO: what about other bit depths?
					allMyPixels[i] = Color_RGBA(0, 0, 0, 0);
				}
            } else {
				if (IHDR.bitDepth == PngIHDRBitDepth.BitDepth16) {
					allMyPixels[i] = Color_RGBA(pixel.value, pixel.value, pixel.value, pixel.a);
				} else if (IHDR.bitDepth == PngIHDRBitDepth.BitDepth8) {
					allMyPixels[i] = Color_RGBA(cast(ushort)(pixel.value * ubyteToUshort),
					                            cast(ushort)(pixel.value * ubyteToUshort),
					                            cast(ushort)(pixel.value * ubyteToUshort),
					                            cast(ushort)(pixel.a * ubyteToUshort));
				} else {
					// TODO: what about other bit depths?
					allMyPixels[i] = Color_RGBA(0, 0, 0, 0);
				}
            }
        }
    }
}

void decompressInflateDeflate(PngImage _, ubyte[] chunkData,
out ubyte[] uncompressed, out size_t expectedSize, out size_t colorSize) {
    import std.zlib : uncompress;

    with(_) {
		if (IHDR.colorType == PngIHDRColorType.Palette || IHDR.colorType == PngIHDRColorType.Grayscale) {
            colorSize = 1;
        } else if (IHDR.colorType == PngIHDRColorType.PalletteWithColorUsed || IHDR.colorType == PngIHDRColorType.AlphaChannelUsed) {
            colorSize = 2;
        } else if (IHDR.colorType == PngIHDRColorType.ColorUsed) {
            colorSize = 3;
        } else if (IHDR.colorType == PngIHDRColorType.ColorUsedWithAlpha) {
            colorSize = 4;
        }

        switch(IHDR.bitDepth) {
            case PngIHDRBitDepth.BitDepth8:
            case PngIHDRBitDepth.BitDepth4:
            case PngIHDRBitDepth.BitDepth2:
            case PngIHDRBitDepth.BitDepth1:
                expectedSize += colorSize;
                break;
                
            case PngIHDRBitDepth.BitDepth16:
                colorSize *= 2;
                expectedSize += colorSize;
                break;
                
            default:
                throw new NotAnImageException("Unknown bit depth");
        }

		expectedSize *= IHDR.height * IHDR.width;

		if (IHDR.filterMethod == PngIHDRFilter.Adaptive) {
			// add one per scan line
			expectedSize += IHDR.height;
		}

	}
    uncompressed = cast(ubyte[])uncompress(chunkData, expectedSize);
}

ubyte[][] grabPixelsRawData(PngImage _, ubyte[] rawData, ref ubyte[] adaptiveOffsets, size_t colorSize) {
    ubyte[][] ret;

    with(_) {
        size_t sinceLast = IHDR.width - 1;
        size_t i;

        while(i < rawData.length) {
            if (IHDR.filterMethod == PngIHDRFilter.Adaptive) {
                if (sinceLast == IHDR.width - 1) {
                    // finished a scan line
                    adaptiveOffsets ~= rawData[i];
                    sinceLast = 0;
                    i++;
                } else {
                    sinceLast++;
                }

                ret ~= rawData[i .. i + colorSize];

                i += colorSize;
            } // else if ...
        }
    }

    return ret;
}

IDAT_Chunk_Pixel[] adaptivePixelGrabber(PngImage _, ubyte[][] data, ubyte[] filters, size_t colorSize) {
    size_t scanLine = 0;
    IDAT_Chunk_Pixel[] pixels;

    with(_) {
		ubyte[][] lastPixelData;

		foreach(pixel, pixelData; data) {
            ubyte[] thePixel = pixelData.dup;
			size_t pI = pixel % IHDR.width;

            // unfilter
            switch(filters[scanLine]) {
                case 1: // sub
                    // Sub(x) + Raw(x-bpp)
                    
					if (pI > 0) {
						foreach(j; 0 .. colorSize) {
							ubyte rawSub = lastPixelData[pixel-1][j];
                        	thePixel[j] = cast(ubyte)(pixelData[j] + rawSub);
                    	}
					} else {
						// no changes needed
					}

                    break;
                    
                case 2: // up
                    // Up(x) + Prior(x)
                    
					if (scanLine > 0) {
                        foreach(j; 0 .. pixelData.length) {
							ubyte prior = lastPixelData[(scanLine - 1) * _.width + pI][j];
							thePixel[j] = cast(ubyte)(pixelData[j] + prior);
                        }
                    } else {
						// no changes needed
                    }
                    break;
                    
                case 3: // average
                    import std.math : floor;
                    // Average(x) + floor((Raw(x-bpp)+Prior(x))/2)
                    
					if (scanLine > 0 && pI > 0) {
						foreach(j; 0 .. colorSize) {
							ubyte prior = lastPixelData[(scanLine - 1) * _.width + pI][j];
							ubyte rawSub = lastPixelData[pixel-1][j];
							thePixel[j] = cast(ubyte)(pixelData[j] + floor(cast(real)(rawSub + prior) / 2f));
	                    }
					} else if (scanLine > 0 && pI == 0) {
						foreach(j; 0 .. colorSize) {
							ubyte prior = lastPixelData[(scanLine - 1) * _.width + pI][j];
							ubyte rawSub = 0;
							thePixel[j] = cast(ubyte)(pixelData[j] + floor(cast(real)(rawSub + prior) / 2f));
						}
					} else if (scanLine == 0 && pI > 0) {
						foreach(j; 0 .. colorSize) {
							ubyte prior = 0;
							ubyte rawSub = lastPixelData[pixel-1][j];
							thePixel[j] = cast(ubyte)(pixelData[j] + floor(cast(real)(rawSub + prior) / 2f));
						}
					} else {
						// no changes needed
					}
					break;
                    
                case 4: // paeth
                    //  Paeth(x) + PaethPredictor(Raw(x-bpp), Prior(x), Prior(x-bpp))
                    
					if (scanLine > 0 && pI > 0) {
						foreach(j; 0 .. colorSize) {
							ubyte prior = lastPixelData[(scanLine - 1) * _.width + pI][j];
							ubyte rawSub = lastPixelData[pixel-1][j];
							ubyte priorRawSub = lastPixelData[(scanLine - 1) * _.width + (pI-1)][j];

							thePixel[j] = cast(ubyte)(pixelData[j] + PaethPredictor(rawSub, prior, priorRawSub));
	                    }
					} else if (scanLine > 0 && pI == 0) {
						foreach(j; 0 .. colorSize) {
							ubyte prior = lastPixelData[(scanLine - 1) * _.width + pI][j];
							ubyte rawSub = 0;
							ubyte priorRawSub = 0;

							thePixel[j] = cast(ubyte)(pixelData[j] + PaethPredictor(rawSub, prior, priorRawSub));
						}
					} else if (scanLine == 0 && pI > 0) {
						foreach(j; 0 .. colorSize) {
							ubyte prior = 0;
							ubyte rawSub = lastPixelData[pixel-1][j];
							ubyte priorRawSub = 0;

							thePixel[j] = cast(ubyte)(pixelData[j] + PaethPredictor(rawSub, prior, priorRawSub));
						}
					} else {
						// no changes needed
					}
                    
                    break;
                    
                default:
                case 0: // none
                    break;
            }

			lastPixelData ~= thePixel;
            pixels ~= new IDAT_Chunk_Pixel(thePixel, IHDR.bitDepth == PngIHDRBitDepth.BitDepth16);

            if (pixel % IHDR.width == IHDR.width-1) {
                scanLine++;
            }
        }
    }

    return pixels;
}

ubyte PaethPredictor(ubyte a, ubyte b, ubyte c) {
    import std.math : abs;

    // a = left, b = above, c = upper left
    int p = a + b - c;        // initial estimate
    int pa = abs(p - a);      // distances to a, b, c
    int pb = abs(p - b);
    int pc = abs(p - c);

    // return nearest of a,b,c,
    // breaking ties in order a,b,c.
    if (pa <= pb && pa <= pc) return a;
    else if (pb <= pc) return b;
    else return c;
}