//---------------------------------------------------------------------------------
//
//  Silica demo for Nintendo 3DS -- Embedded Swift ARM11 binary.
//
//  A slideshow of vector-graphics drawings (Silica's CGContext API, rasterized
//  by the Silica3DS software renderer) on the top screen. The slide content
//  lives in Sources/Silica3DS/DemoSlides.swift, shared with a host-side
//  render-dump test so the exact same drawing code can be inspected without
//  a 3DS or emulator.
//
//    L / R / D-PAD    previous / next slide
//    START            exit
//
//---------------------------------------------------------------------------------

import CTRU
#if canImport(Silica3DS)
import Silica3DS
#endif

gfxInitDefault()
gfxSetDoubleBuffering(GFX_TOP, false)

// text console on the bottom screen
consoleInit(GFX_BOTTOM, nil)

let slides = Silica3DSDemo.slides

var currentSlide = 0
let context = try! Nintendo3DSContext(screen: .top, scale: 2)

func showCurrentSlide() {
    slides[currentSlide].draw(context)
    context.present()

    consoleClear()
    ctru_puts("\n  Silica on Nintendo 3DS\n")
    ctru_puts("  Software-rendered CGContext\n\n")
    ctru_printf_1i("  Slide %d", Int32(currentSlide + 1))
    ctru_printf_1i(" / %d\n", Int32(slides.count))
    ctru_puts("  ")
    ctru_puts(slides[currentSlide].name)
    ctru_puts("\n\n")
    ctru_puts("  L/R or D-PAD  change slide\n")
    ctru_puts("  START         exit\n")
}

showCurrentSlide()

// MARK: - Main loop

while aptMainLoop() {

    // gspWaitForVBlank() is a macro; call its expansion directly
    gspWaitForEvent(GSPGPU_EVENT_VBlank0, true)
    hidScanInput()

    let pressed = hidKeysDown()

    if pressed & KEY_START != 0 {
        break
    }

    var changed = false

    if pressed & (KEY_R | KEY_RIGHT) != 0 {
        currentSlide = (currentSlide + 1) % slides.count
        changed = true
    }

    if pressed & (KEY_L | KEY_LEFT) != 0 {
        currentSlide = (currentSlide - 1 + slides.count) % slides.count
        changed = true
    }

    if changed {
        showCurrentSlide()
    }
}

gfxExit()
