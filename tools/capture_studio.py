import ctypes
import sys
from ctypes import wintypes

from PIL import Image

User32 = ctypes.windll.user32
Gdi32 = ctypes.windll.gdi32


def FindStudioWindow():
    Found = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    def OnWindow(Handle, _):
        Length = User32.GetWindowTextLengthW(Handle)

        if Length == 0 or not User32.IsWindowVisible(Handle):
            return True

        Title = ctypes.create_unicode_buffer(Length + 1)
        User32.GetWindowTextW(Handle, Title, Length + 1)

        if Title.value.endswith("Roblox Studio"):
            Found.append(Handle)

        return True

    User32.EnumWindows(OnWindow, 0)

    return Found[0] if Found else None


def CaptureWindow(Handle):
    Rect = wintypes.RECT()
    User32.GetWindowRect(Handle, ctypes.byref(Rect))
    Width = Rect.right - Rect.left
    Height = Rect.bottom - Rect.top
    WindowContext = User32.GetWindowDC(Handle)
    MemoryContext = Gdi32.CreateCompatibleDC(WindowContext)
    Bitmap = Gdi32.CreateCompatibleBitmap(WindowContext, Width, Height)
    Gdi32.SelectObject(MemoryContext, Bitmap)
    User32.PrintWindow(Handle, MemoryContext, 2)

    class BitmapInfoHeader(ctypes.Structure):
        _fields_ = [
            ("biSize", wintypes.DWORD),
            ("biWidth", wintypes.LONG),
            ("biHeight", wintypes.LONG),
            ("biPlanes", wintypes.WORD),
            ("biBitCount", wintypes.WORD),
            ("biCompression", wintypes.DWORD),
            ("biSizeImage", wintypes.DWORD),
            ("biXPelsPerMeter", wintypes.LONG),
            ("biYPelsPerMeter", wintypes.LONG),
            ("biClrUsed", wintypes.DWORD),
            ("biClrImportant", wintypes.DWORD),
        ]

    Header = BitmapInfoHeader()
    Header.biSize = ctypes.sizeof(BitmapInfoHeader)
    Header.biWidth = Width
    Header.biHeight = -Height
    Header.biPlanes = 1
    Header.biBitCount = 32
    Pixels = ctypes.create_string_buffer(Width * Height * 4)
    Gdi32.GetDIBits(MemoryContext, Bitmap, 0, Height, Pixels, ctypes.byref(Header), 0)
    Gdi32.DeleteObject(Bitmap)
    Gdi32.DeleteDC(MemoryContext)
    User32.ReleaseDC(Handle, WindowContext)

    return Image.frombuffer("RGB", (Width, Height), Pixels, "raw", "BGRX", 0, 1)


if __name__ == "__main__":
    Handle = FindStudioWindow()

    if not Handle:
        sys.exit("No Roblox Studio window is open")

    Picture = CaptureWindow(Handle)

    if len(sys.argv) > 5:
        Left, Top, Right, Bottom = (int(Value) for Value in sys.argv[2:6])
        Picture = Picture.crop((Left, Top, Right, Bottom))

    Picture.save(sys.argv[1])
    print(sys.argv[1], Picture.size)
