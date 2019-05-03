# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Cliptomania clipboard library v0.1
# Developed in 2019 by V.A. Guevara
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #

# [OS-dependent bindings]
when defined(windows):
    type
        Point = object
            x, y: int32
        DropFiles = object
            pFiles:     int32
            pt:         Point
            fNC, fWide: int32
    # •Clipboard•
    proc open_clipboard(hwnd: int = 0): cint       {.stdcall, dynlib: "user32", importc: "OpenClipboard",  discardable.}
    proc close_clipboard(): cint                   {.stdcall, dynlib: "user32", importc: "CloseClipboard", discardable.}
    proc empty_clipboard(): cint                   {.stdcall, dynlib: "user32", importc: "EmptyClipboard", discardable.}
    proc get_clipboard_data(format: uint): pointer {.stdcall, dynlib: "user32", importc: "GetClipboardData".}
    proc set_clipboard_data(format:uint, mem:pointer): pointer {.stdcall, dynlib:"user32", importc:"SetClipboardData".}
    proc clipboard_format_available(format:uint): cint {.stdcall, dynlib:"user32",importc:"IsClipboardFormatAvailable".}
    # •Global memory•
    proc global_size(mem: pointer): cint           {.stdcall, dynlib: "kernel32", importc: "GlobalSize".}
    proc global_lock(mem: pointer): pointer        {.stdcall, dynlib: "kernel32", importc: "GlobalLock".}
    proc global_alloc(flags:uint,size:int):pointer {.stdcall, dynlib: "kernel32", importc: "GlobalAlloc".}
    proc global_unlock(mem: pointer): cint         {.stdcall, dynlib: "kernel32", importc: "GlobalUnlock", discardable.}
else: {.fatal: "FAULT:: only Windows OS is supported for now !".}

#.{ [Classes]
when not defined(clip):
    # --Service definitions:
    type
        clip*        = object
        ClipFragment = tuple[format: clip_formats, data: seq[byte]]
        clip_formats = enum
            text = 1, bitmap, metafile_picture, symbolic_link, dif, tiff, oem_text, dib, palette, pen_data, riff, 
            wave_audio, unicode_text, enhanced_metafile, file_drop, locale, dib_v5
    template formats*(_: type clip): auto  = clip_formats
    template fragment*(_: type clip): auto = ClipFragment
    using
        Δ: type clip

    # --Methods goes here:
    # •Aux converters & helpers•
    converter to_clip_fragment*(src: string): clip.fragment =
        var wide_text = newWideCString(src)
        var buffer = newSeq[byte](wide_text.len * 2 + 2)
        buffer[0].addr.copyMem wide_text[0].addr, buffer.len
        return (format: clip.formats.unicode_text, data: buffer)

    converter to_clip_fragment*(src: seq[string]): clip.fragment =
        var 
            buffer = newSeq[int16](DropFiles.sizeOf shr 1)
            header = DropFiles(fWide: 1, pFiles: DropFiles.sizeOf.int32)
        buffer[0].addr.copyMem header.addr, header.sizeOf
        for entry in src:
            var utf16_path = cast[seq[int16]](entry.to_clip_fragment.data)
            utf16_path.setLen utf16_path.len shr 1
            for c in utf16_path: buffer &= c
        buffer &= 0.int16
        buffer.setLen buffer.len * 2
        return (format: clip.formats.file_drop, data: cast[seq[byte]](buffer))

    proc `$`*(src: clip.fragment): string =
        var utf16 = src.data
        return $cast[WideCString](utf16[0].addr)

    converter to_drop_list*(src: clip.fragment): seq[string] =
        var feed = src.data
        result = newSeq[string](0)
        var utf16_feed = cast[seq[int16]](feed)
        utf16_feed.setLen feed.len
        if feed.len > 0:
            var 
                header: DropFiles
                accum: seq[int16] = @[]
            header.addr.copyMem feed[0].addr, header.sizeOf
            for idx, byte in feed[header.pFiles..^1]:
                let c = (if header.fWide == 0: byte.int16 else: utf16_feed[idx+header.pFiles shr 1])
                if c != 0: accum &= c
                elif accum != @[]:
                    accum.setLen accum.len * 2
                    result.add($(format: clip.formats.text, data: cast[seq[byte]](accum)))
                    accum = @[]

    converter to_byte_seq(src: clip.fragment): seq[byte] =
        src.data

    # •Public methods•
    proc get_data_list*(Δ; formats: varargs[clip.formats]): seq[clip.fragment] =
        result = newSeq[clip.fragment](0)
        open_clipboard()
        for format in formats:
            let data = format.uint.get_clipboard_data
            let data_size = data.global_size
            if data_size > 0:
                let feed = data.global_lock
                var buffer = newSeq[byte](data_size)
                buffer[0].addr.copyMem feed, data_size
                data.global_unlock
                result.add (format, buffer)
            else: result.add (format, @[])
        close_clipboard()

    proc set_data_list*(Δ; list: varargs[clip.fragment]) =
        open_clipboard()
        empty_clipboard()
        for entry in list:
            var (format, data) = entry
            let buffer = 66.global_alloc data.len
            let dest = buffer.global_lock
            dest.copyMem data[0].addr, data.len
            buffer.global_unlock
            discard format.uint.set_clipboard_data buffer
        close_clipboard()

    proc clear*(Δ) {.inline.} =
        clip.set_data_list

    proc get_data*(Δ; format: clip.formats): clip.fragment {.inline.} =
        clip.get_data_list(format)[0]

    proc set_data*(Δ; format: clip.formats, data: seq[byte]) {.inline.} =
        clip.set_data_list (format, data)

    proc set_data*(Δ; fragment: clip.fragment) {.inline.} =
        clip.set_data_list (fragment.format, fragment.data)

    proc contains_data*(Δ; format: clip.formats): bool {.inline.} =
        format.uint.clipboard_format_available != 0

    proc get_text*(Δ): string {.inline.} =
        return $clip.get_data clip.formats.unicode_text

    proc set_text*(Δ; text: string) {.inline.} =
        clip.set_data text

    proc contains_text*(Δ): bool {.inline.} =
        clip.contains_data clip.formats.unicode_text

    proc get_file_drop_list*(Δ): seq[string] {.inline.}=
        clip.get_data clip.formats.file_drop

    proc set_file_drop_list*(Δ; list: seq[string]) {.inline.} =
        clip.set_data list

    proc contains_file_drop_list*(Δ): bool {.inline.} =
        clip.contains_data clip.formats.file_drop
#.}

# ==Testing code==
when isMainModule: include "../examples/basic.nim"