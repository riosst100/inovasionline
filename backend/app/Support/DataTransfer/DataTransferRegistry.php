<?php

namespace App\Support\DataTransfer;

use App\Support\DataTransfer\Handlers\BrandTransferHandler;
use App\Support\DataTransfer\Handlers\CategoryTransferHandler;
use App\Support\DataTransfer\Handlers\ProductStockTransferHandler;
use App\Support\DataTransfer\Handlers\ProductTransferHandler;
use App\Support\DataTransfer\Handlers\SupplierTransferHandler;
use App\Support\DataTransfer\Handlers\WarehouseTransferHandler;
use InvalidArgumentException;

class DataTransferRegistry
{
    /**
     * Resource key => handler class. The key, with dashes as underscores, is also the admin menu
     * (AdminMenu) whose view/manage permission allows exporting/importing it.
     *
     * @var array<string, class-string<TransferHandler>>
     */
    public const HANDLERS = [
        'categories' => CategoryTransferHandler::class,
        'products' => ProductTransferHandler::class,
        'warehouses' => WarehouseTransferHandler::class,
        'product-stocks' => ProductStockTransferHandler::class,
        'suppliers' => SupplierTransferHandler::class,
        'brands' => BrandTransferHandler::class,
    ];

    /** @return array<int, string> */
    public static function resources(): array
    {
        return array_keys(self::HANDLERS);
    }

    /** Admin menu key guarding this resource. */
    public static function menu(string $resource): string
    {
        return str_replace('-', '_', $resource);
    }

    public static function handler(string $resource): TransferHandler
    {
        $class = self::HANDLERS[$resource] ?? throw new InvalidArgumentException("Unknown data transfer resource: {$resource}");

        return app($class);
    }
}
