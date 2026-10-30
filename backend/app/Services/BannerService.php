<?php

namespace App\Services;

use App\Support\ImageOptimizer;
use App\Models\Banner;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class BannerService
{
    /**
     * @param  array<string, mixed>  $data
     */
    public function create(array $data, ?UploadedFile $image = null): Banner
    {
        $placement = $data['placement'] ?? Banner::PLACEMENT_SLIDER;
        $nextSortOrder = ((int) Banner::query()->where('placement', $placement)->max('sort_order')) + 1;
        $imagePath = $image !== null ? ImageOptimizer::store($image, 'banners', 1600) : ($data['image_url'] ?? '');

        return Banner::create([
            'name' => $data['name'],
            'image_path' => $imagePath,
            'link_url' => $data['link_url'] ?? null,
            'placement' => $placement,
            'is_active' => isset($data['is_active']) ? filter_var($data['is_active'], FILTER_VALIDATE_BOOLEAN) : true,
            'starts_on' => $data['starts_on'] ?? null,
            'ends_on' => $data['ends_on'] ?? null,
            'sort_order' => $data['sort_order'] ?? $nextSortOrder,
        ]);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Banner $banner, array $data, ?UploadedFile $image = null): Banner
    {
        if ($image !== null) {
            if ($banner->image_path && !str_starts_with($banner->image_path, 'http')) {
                Storage::disk('public')->delete($banner->image_path);
            }
            $data['image_path'] = ImageOptimizer::store($image, 'banners', 1600);
        } elseif (!empty($data['image_url'])) {
            $data['image_path'] = $data['image_url'];
        }

        if (array_key_exists('is_active', $data)) {
            $data['is_active'] = filter_var($data['is_active'], FILTER_VALIDATE_BOOLEAN);
        }

        unset($data['image']);
        unset($data['image_url']);

        $banner->update($data);

        return $banner;
    }

    /**
     * @param  string[]  $orderedIds
     */
    public function reorder(array $orderedIds): void
    {
        DB::transaction(function () use ($orderedIds) {
            foreach ($orderedIds as $index => $id) {
                Banner::query()->whereKey($id)->update(['sort_order' => $index + 1]);
            }
        });
    }

    public function delete(Banner $banner): void
    {
        if ($banner->image_path && !str_starts_with($banner->image_path, 'http')) {
            Storage::disk('public')->delete($banner->image_path);
        }
        $banner->delete();
    }
}
