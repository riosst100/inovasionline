<?php

namespace App\Console\Commands;

use App\Models\DeviceToken;
use Illuminate\Console\Command;
use Kreait\Firebase\Contract\Messaging;

class PruneDeviceTokens extends Command
{
    protected $signature = 'push:prune-tokens
        {--stale-days=270 : Also delete tokens not re-registered for this many days (FCM expires them after ~270)}
        {--dry-run : Only report what would be deleted}';

    protected $description = 'Delete FCM device tokens that Firebase reports as dead (dry-run validation, nothing is delivered)';

    public function handle(Messaging $messaging): int
    {
        $dry = (bool) $this->option('dry-run');
        $dead = [];

        // FCM validates at most 500 tokens per multicast.
        DeviceToken::query()->select('token')->chunk(500, function ($rows) use ($messaging, &$dead) {
            $report = $messaging->validateRegistrationTokens($rows->pluck('token')->all());
            array_push($dead, ...$report['invalid'], ...$report['unknown']);
        });

        $stale = DeviceToken::query()
            ->where('last_seen_at', '<', now()->subDays((int) $this->option('stale-days')))
            ->pluck('token')
            ->all();

        $all = array_values(array_unique([...$dead, ...$stale]));

        $this->info(sprintf('%d dead by FCM, %d stale, %d to delete.', count($dead), count($stale), count($all)));

        if (! $dry && $all !== []) {
            DeviceToken::query()->whereIn('token', $all)->delete();
        }

        return self::SUCCESS;
    }
}
