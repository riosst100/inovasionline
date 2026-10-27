<?php

namespace App\Console\Commands;

use App\Models\Banner;
use App\Models\Category;
use App\Models\OrderItem;
use App\Models\PostMedia;
use App\Models\ProductImage;
use App\Support\Enums\PostMediaType;
use App\Support\ImageOptimizer;
use Illuminate\Console\Command;

class OptimizeImages extends Command
{
    protected $signature = 'images:optimize {--dry-run : Only report what would be recompressed}';

    protected $description = 'Recompress already-uploaded product, banner, category and post images to downscaled WebP';

    public function handle(): int
    {
        $dry = (bool) $this->option('dry-run');

        $targets = [
            [ProductImage::query(), 'path', ImageOptimizer::MAX_SIDE],
            [Banner::query(), 'image_path', 1600],
            [Category::query(), 'image_path', 600],
            [PostMedia::query()->where('type', PostMediaType::IMAGE), 'path', ImageOptimizer::MAX_SIDE],
        ];

        $changed = 0;
        foreach ($targets as [$query, $column, $maxSide]) {
            $query->whereNotNull($column)->each(function ($row) use ($column, $maxSide, $dry, &$changed) {
                $path = $row->{$column};
                if (! $path || str_starts_with($path, 'http')) {
                    return;
                }

                if ($dry) {
                    $this->line("would recompress {$path}");
                    $changed++;

                    return;
                }

                $newPath = ImageOptimizer::recompress($path, $maxSide);
                if ($newPath !== null) {
                    // Orders keep their own copy of the product image path.
                    OrderItem::query()->where('product_image_path', $path)->update(['product_image_path' => $newPath]);
                    $row->forceFill([$column => $newPath])->saveQuietly();
                    $changed++;
                }
            });
        }

        $this->info(($dry ? 'Candidates: ' : 'Recompressed: ').$changed);

        return self::SUCCESS;
    }
}
