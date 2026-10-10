<?php

namespace App\Jobs;

use App\Models\UserFaceProfile;
use App\Services\FaceMatchService;
use App\Services\PhotoMatchService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class MatchSelfieAgainstPhotosJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public readonly UserFaceProfile $profile) {}

    public function handle(FaceMatchService $faceMatchService, PhotoMatchService $photoMatchService): void
    {
        $faces = $faceMatchService->embed($this->profile->selfie_path);

        if (empty($faces)) {
            $this->profile->update(['status' => 'failed']);

            return;
        }

        // A selfie should contain exactly one person; use the highest
        // confidence detection if more than one face was found in the frame.
        $primaryFace = collect($faces)->sortByDesc('det_score')->first();

        $this->profile->update([
            'embedding' => $primaryFace['embedding'],
            'status' => 'ready',
        ]);

        $photoMatchService->matchUserAgainstAllPhotos($this->profile->fresh());
    }
}
