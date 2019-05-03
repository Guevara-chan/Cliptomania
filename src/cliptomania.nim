# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Cliptomania clipboard library v0.1
# Developed in 2019 by V.A. Guevara
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
import unicode

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
    proc set_clipboard_data(format:uint, mem:pointer): pointer {.stdcall, dynlib: "user32", importc: "SetClipboardData".}
    proc clipboard_format_available(format:uint): cint {.stdcall, dynlib:"user32", importc:"IsClipboardFormatAvailable".}
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
        clip         = object
        Bytes        = seq[byte]
        scrap        = tuple[format: clip_formats, data: Bytes]
        clip_formats = enum
            text = 1, bitmap, metafile_picture, symbolic_link, dif, tiff, oem_text, dib, palette, pen_data, riff, 
            wave_audio, unicode_text, enhanced_metafile, file_drop, locale, dib_v5
    template formats*(_: type clip): auto = clip_formats
    using
        Δ: type clip

    # --Methods goes here:
    # •Aux converters•
    converter toBytes(src: string): Bytes =
        var wide_text = newWideCString(src)
        result = newSeq[byte](wide_text.len * 2 + 2)
        result[0].addr.copyMem wide_text[0].addr, result.len

    proc `$`*(src: Bytes): string =
        var utf16 = src
        return $(cast[WideCString](utf16[0].addr))

    # •Public methods•
    proc clear*(Δ) =
        open_clipboard()
        empty_clipboard()
        close_clipboard()

    proc get_data_list*(Δ; formats: varargs[clip.formats]): seq[scrap] =
        result = newSeq[scrap](0)
        open_clipboard()
        for format in formats:
            let data = format.uint.get_clipboard_data
            let data_size = data.global_size
            if data_size > 0:
                let feed = data.global_lock
                var buffer = newSeq[byte](data_size)
                buffer[0].addr.copyMem feed, data_size
                data.global_unlock
                result.add((format, buffer))
            else: result.add((format, @[]))
        close_clipboard()

    proc set_data_list*(Δ; list: varargs[scrap]) =
        open_clipboard()
        empty_clipboard()
        for entry in list:
            var (format, data) = entry
            let buffer = 66.global_alloc(data.len)
            let dest = buffer.global_lock
            dest.copyMem data[0].addr, data.len
            buffer.global_unlock
            discard format.uint.set_clipboard_data(buffer)
        close_clipboard()

    proc get_data*(Δ; format: clip.formats): Bytes =
        clip.get_data_list(format)[0].data        

    proc set_data*(Δ; format: clip.formats, data: Bytes) =
        clip.set_data_list((format, data))

    proc contains_data*(Δ; format: clip.formats): bool =
        format.uint.clipboard_format_available != 0

    proc get_text*(Δ): string =
        return $(clip.get_data(clip.formats.unicode_text))

    proc set_text*(Δ; text: string) =
        clip.set_data(clip.formats.unicode_text, text)

    proc contains_text*(Δ): bool =
        clip.contains_data(clip.formats.unicode_text)

    proc get_file_drop_list*(Δ): seq[string] =
        result = newSeq[string](0)
        var feed = clip.get_data(clip.formats.file_drop)
        let utf16_feed = cast[seq[Rune16]](feed)
        if feed.len > 0:
            let header = cast[DropFiles](feed[0].addr)
            var accum = ""
            for idx, byte in feed[header.sizeOf..^1]:
                let c = (if header.fWide == 0: byte.Rune else: utf16_feed[idx+header.sizeOf shr 1].Rune)
                if c.int != 0: accum &= $c
                elif accum != "": result.add(accum); accum = ""

    proc set_file_drop_list*(Δ; list: seq[string]) =
        var
            buffer = newSeq[int16](DropFiles.sizeOf shr 1)
            header = cast[DropFiles](buffer)
        header.fWide = 1
        for entry in list:
            for c in entry.runes: buffer &= c.int16
            buffer &= 0.int16
        for i in 1..2: buffer &= 0.int16
        buffer.setLen buffer.len * 2
        clip.set_data clip.formats.file_drop, cast[seq[byte]](buffer)

    proc contains_file_drop_list*(Δ): bool =
        clip.contains_data(clip.formats.file_drop)
#.}

# ==Testing code==
when isMainModule:
    clip.set_text("Hallo there.")
    if clip.contains_text: echo clip.get_text()
    clip.set_file_drop_list(@[r"C:\a.txt"])
    if clip.contains_file_drop_list: echo clip.get_file_drop_list()