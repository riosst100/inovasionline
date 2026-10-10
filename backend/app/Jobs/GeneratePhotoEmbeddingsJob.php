<?php

namespace App\Jobs;

use App\Models\Photo;
use App\Services\FaceMatchService;
use App\Support\Enums\PhotoStatus;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class GeneratePhotoEmbeddingsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public readonly Photo $photo) {}

    public function handle(FaceMatchService $faceMatchService): void
    {
        $faces = $faceMatchService->embed($this->photo->path);

        $this->photo->update([
            'embeddings' => $faces,
            'face_count' => count($faces),
            'status' => PhotoStatus::PUBLISHED,
        ]);

        if (! empty($faces)) {
            MatchPhotoAgainstFaceProfilesJob::dispatch($this->photo->fresh());
        }
    }
}
