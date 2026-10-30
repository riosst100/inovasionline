<?php

namespace Tests\Feature;

use Tests\TestCase;

/** Guards against tests running on the development database (RefreshDatabase wipes it). */
class DatabaseIsolationTest extends TestCase
{
    public function test_tests_use_the_dedicated_testing_database(): void
    {
        $connection = config('database.default');
        $database = (string) config("database.connections.$connection.database");

        $this->assertStringEndsWith('_testing', $database, "Tests are pointed at '$database', not a *_testing database.");
    }

    public function test_tests_do_not_write_to_the_search_index(): void
    {
        // env() turns "null" into null, which Scout treats as the null driver.
        $this->assertSame('null', config('scout.driver') ?? 'null', 'Tests would sync models into the development Meilisearch index.');
    }
}
