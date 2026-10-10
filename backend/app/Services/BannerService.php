<?php

namespace App\Services;

use App\Models\Banner;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class BannerService
{
    /**
     * @param  array<string, mixed>  $data
     */
    public function create(array $data, UploadedFile $image): Banner
    {
        $nextSortOrder = ((int) Banner::query()->max('sort_order')) + 1;

        return Banner::create([
            ...$data,
            'image_path' => $image->store('banners', 'public'),
            'is_active' => $data['is_active'] ?? true,
            'sort_order' => $nextSortOrder,
        ]);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Banner $banner, array $data, ?UploadedFile $image): Banner
    {
        if ($image !== null) {
            Storage::disk('public')->delete($banner->image_path);
            $data['image_path'] = $image->store('banners', 'public');
        }

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
                Banner::query()->whereKey($id)->update(['sort_order' => $index]);
            }
        });
    }

    public function delete(Banner $banner): void
    {
        Storage::disk('public')->delete($banner->image_path);
        $banner->delete();
    }
}
