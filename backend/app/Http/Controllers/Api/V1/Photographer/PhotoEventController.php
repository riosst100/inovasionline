<?php

namespace App\Http\Controllers\Api\V1\Photographer;

use App\Http\Controllers\Controller;
use App\Http\Requests\Photographer\PhotoEventRequest;
use App\Http\Resources\PhotoEventResource;
use App\Models\PhotoEvent;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PhotoEventController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $paginator = $request->user()->photographer->events()
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, PhotoEventResource::class, 'Events retrieved successfully.');
    }

    public function store(PhotoEventRequest $request): JsonResponse
    {
        $data = $request->validated();

        if ($request->hasFile('cover_photo')) {
            $data['cover_photo_path'] = $request->file('cover_photo')->store('photo-events', 'public');
        }

        $event = $request->user()->photographer->events()->create([
            ...$data,
            'slug' => $this->generateSlug($data['title']),
        ]);

        return ApiResponse::success(new PhotoEventResource($event), 'Event created successfully.', [], 201);
    }

    public function update(PhotoEventRequest $request, PhotoEvent $event): JsonResponse
    {
        $data = $request->validated();

        if ($request->hasFile('cover_photo')) {
            $data['cover_photo_path'] = $request->file('cover_photo')->store('photo-events', 'public');
        }

        $event->update($data);

        return ApiResponse::success(new PhotoEventResource($event), 'Event updated successfully.');
    }

    public function destroy(PhotoEvent $event): JsonResponse
    {
        $event->delete();

        return ApiResponse::success(null, 'Event deleted successfully.');
    }

    private function generateSlug(string $title): string
    {
        $base = Str::slug($title);
        $slug = $base;
        $suffix = 1;

        while (PhotoEvent::where('slug', $slug)->exists()) {
            $slug = "{$base}-{$suffix}";
            $suffix++;
        }

        return $slug;
    }
}
