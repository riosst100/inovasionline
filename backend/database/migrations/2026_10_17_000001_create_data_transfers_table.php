<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('data_transfers', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('type', 10); // import | export
            $table->string('resource', 50); // categories, products, ...
            $table->string('format', 10); // csv | xlsx
            $table->string('status', 20)->default('pending');
            $table->string('file_name')->nullable();
            $table->string('file_path')->nullable();
            $table->json('filters')->nullable();
            $table->unsignedInteger('total_rows')->default(0);
            $table->unsignedInteger('processed_rows')->default(0);
            $table->unsignedInteger('created_rows')->default(0);
            $table->unsignedInteger('updated_rows')->default(0);
            $table->unsignedInteger('failed_rows')->default(0);
            $table->json('row_errors')->nullable();
            $table->text('error_message')->nullable();
            $table->ulid('admin_user_id')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();

            $table->foreign('admin_user_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['resource', 'created_at']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('data_transfers');
    }
};
