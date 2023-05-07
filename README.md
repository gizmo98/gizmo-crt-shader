# gizmo-crt-shader

This libretro shader tries to mimic crt behaviour without extensive use of scanlines and replicating CRT pixel patterns. 

## Assumptions for shader development
- CRT output is much more vivid compared to a LCD. There a small deviations in color and position. A CRT always seems to restless.
- A CRT has no fixed resolution. Fractional scaling is no problem. 
- If you take a look at CRT vs LCD comparisons it's obvious that phosphor not only changes color from black to red/green/blue. The spatial extent also changes. Scanlines are good visible in dark regions but they are almost invisible in bright regions.

## Implementation
- A small portion of static noise was added to make the output a little bit restless
- To allow fractional scaling, horizontal subpixel scaling for LCDs with RGB patterns was implemented. To get smooth vertical scaling "improved bilinear interpolation" from Inigo Quilez was implemented.
- A scanline or "pixel separation" function was implemented which takes the brightness of the current pixel into account and produces a thicker or thinner "scanline".

### Examples

#### Subpixel scaling
![subpixel scaling](https://user-images.githubusercontent.com/6412699/233806382-59d4b984-7bb1-4481-bf21-75cd593dd723.png)

#### Scanlines
![scanlines](https://user-images.githubusercontent.com/6412699/233806373-d1eb7ba1-576f-498f-a54e-336f1a3f8ae8.png)
![240p test suite - 2](https://user-images.githubusercontent.com/6412699/233807008-cbbd909a-49a7-45f0-b064-e87ed55ed568.PNG)
![Scanlines](https://user-images.githubusercontent.com/6412699/236659972-74838e94-0373-47fe-8ad2-4cf7dc91f3ba.PNG)

#### Horizontal Blur
![colour bleeding](https://user-images.githubusercontent.com/6412699/236660017-26682414-3ea2-4dee-ba20-a6f3d26070b6.png)

## Variants
# gizmo-crt.glslp
Default v0.3 variant.

# gizmo-crt-n64.glslp
Default v0.3 variant with vertical and horizontal blur for n64.

# gizmo-crt-megadrive.glslp
Default v0.3 variant with horizontal blur and 4:3 aspect for megadrive.

# gizmo-crt-snes.glslp
Default v0.3 variant with 4:3 aspect for snes.

## Results
![240p test suite - 1](https://user-images.githubusercontent.com/6412699/233807021-fab24872-67f6-4b24-9cf6-d35d663cd763.PNG)
![starfox - 1](https://user-images.githubusercontent.com/6412699/233806540-dd52e1aa-f5b7-4e33-a53f-920c28066a50.PNG)
![SOM-gizmo-crt-rgb_2](https://user-images.githubusercontent.com/6412699/233806608-a91368a9-d3c7-4aed-97c4-b3de61adf24d.PNG)
![sonic (1)](https://user-images.githubusercontent.com/6412699/233858142-a483ffe8-7023-40c2-8f8f-f33daf4e2e8f.png)
![M64-native_res_factor_1-3](https://user-images.githubusercontent.com/6412699/234248661-86006643-8d1f-4694-b9c4-1b3780f9afba.PNG)

### Comparison
#### gizmo-crt
![240p test suite - crt-rgb](https://user-images.githubusercontent.com/6412699/233823225-5acce213-cd8e-4808-874a-931cd3fbe746.PNG)

#### CRT-Royal 
![p240 test suite CRT royale](https://user-images.githubusercontent.com/6412699/233806625-ab8b4658-3db6-4cae-9e4b-d8c8e5b879b8.PNG)

#### CRT-PI
![p240 CRT-PI](https://user-images.githubusercontent.com/6412699/233823215-440c5763-34ac-4054-8733-c63dffc43747.PNG)

#### Nearest neighbor vs shader comparison
![p240 comparison org](https://user-images.githubusercontent.com/6412699/233807532-4b3cbd58-88ff-4c43-8e70-790feafbb599.PNG)
![p240 comparison](https://user-images.githubusercontent.com/6412699/233807474-1f8e1856-7d4e-413f-ab2d-c6bd7cd8568a.PNG)

#### gizmo-crt-n64-curvator vs bilinear vs nearest neighbor
![crt-n64 vs bilinear vs nearest neighbor](https://user-images.githubusercontent.com/6412699/234712310-ab777535-6232-41e4-bbb6-8920ce9c5b4e.png)

