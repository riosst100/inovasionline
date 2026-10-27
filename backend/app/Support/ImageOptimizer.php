<?php

namespace App\Support;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Intervention\Image\Drivers\Gd\Driver;
use Intervention\Image\ImageManager;
use Throwable;

/**
 * Stores uploaded images on the public disk as downscaled WebP so phones don't download
 * multi-megabyte camera originals. Never fails an upload: if the image can't be processed
 * (unsupported format, GD without WebP, animated GIF, ...) the original file is stored as-is.
 */
class ImageOptimizer
{
    public const MAX_SIDE = 1280;
    public const QUALITY = 80;
    public const THUMB_SIDE = 320;
    public const THUMB_QUALITY = 75;

    /** Store an upload under $directory and return its path on the public disk. */
    public static function store(UploadedFile $file, string $directory, int $maxSide = self::MAX_SIDE): string
    {
        $mime = (string) $file->getMimeType();
        if (! in_array($mime, ['image/jpeg', 'image/png', 'image/webp'], true) || ! function_exists('imagewebp')) {
            return $file->store($directory, 'public');
        }

        try {
            $encoded = self::encode($file->getRealPath(), $maxSide);
        } catch (Throwable) {
            return $file->store($directory, 'public');
        }

        $path = trim($directory, '/').'/'.bin2hex(random_bytes(20)).'.webp';
        Storage::disk('public')->put($path, $encoded);
        self::makeThumbnail($file->getRealPath(), $path);

        return $path;
    }

    /** `products/ab.webp` -> `products/thumbs/ab.webp`. Convention-based, so no extra DB column. */
    public static function thumbPath(string $path): string
    {
        $dir = dirname($path);

        return ($dir === '.' ? '' : $dir.'/').'thumbs/'.pathinfo($path, PATHINFO_FILENAME).'.webp';
    }

    /** Public URL of the small version, or null when none exists (clients then fall back to the full image). */
    public static function thumbUrl(?string $path): ?string
    {
        if (! $path || str_starts_with($path, 'http')) {
            return null;
        }
        $thumb = self::thumbPath($path);

        return Storage::disk('public')->exists($thumb) ? asset('storage/'.$thumb) : null;
    }

    /** Write the small version of $sourcePath next to $path. Best effort; failure only means no thumbnail. */
    public static function makeThumbnail(string $sourcePath, string $path): void
    {
        try {
            $image = (new ImageManager(new Driver))->read($sourcePath);
            $image->scaleDown(width: self::THUMB_SIDE, height: self::THUMB_SIDE);
            Storage::disk('public')->put(self::thumbPath($path), (string) $image->toWebp(self::THUMB_QUALITY));
        } catch (Throwable) {
        }
    }

    /**
     * Re-compress a file already on the public disk. Returns the new path, or null when
     * nothing was gained (the original is left untouched in that case).
     */
    public static function recompress(string $path, int $maxSide = self::MAX_SIDE): ?string
    {
        $disk = Storage::disk('public');
        if (! $disk->exists($path) || ! function_exists('imagewebp')) {
            return null;
        }
        if (! preg_match('/\.(jpe?g|png|webp)$/i', $path)) {
            return null;
        }

        try {
            $encoded = self::encode($disk->path($path), $maxSide);
        } catch (Throwable) {
            return null;
        }

        if (strlen($encoded) >= $disk->size($path)) {
            if (! $disk->exists(self::thumbPath($path))) {
                self::makeThumbnail($disk->path($path), $path);
            }

            return null;
        }

        $newPath = preg_replace('/\.[a-zA-Z0-9]+$/', '.webp', $path);
        $disk->put($newPath, $encoded);
        self::makeThumbnail($disk->path($newPath), $newPath);
        if ($newPath !== $path) {
            $disk->delete($path);
        }

        return $newPath;
    }

    private static function encode(string $realPath, int $maxSide): string
    {
        $image = (new ImageManager(new Driver))->read($realPath);
        // Bakes in EXIF rotation (read() does it) and never upscales.
        $image->scaleDown(width: $maxSide, height: $maxSide);

        return (string) $image->toWebp(self::QUALITY);
    }
}
