import { ApiResponse, Role, AdminUser, Driver, DriverOrder, Customer, CustomerDetail, PermissionGroups, PaginatedData, Banner, AdminSession, SearchSuggestion, ProductAttribute, Warehouse, ProductStockRow, RegionItem, ServiceCityOptions, ServiceFeeSettings, WalletBonusSettings, NavBadgeSettings, DeliverySchedule, DeliveryHoliday, ShippingMethod, FlashSale, FlashSalePayload } from '../types';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8001/api';

export class ApiError extends Error {
  errors?: Record<string, string[]>;
  status?: number;

  constructor(message: string, errors?: Record<string, string[]>, status?: number) {
    super(message);
    this.name = 'ApiError';
    this.errors = errors;
    this.status = status;
  }
}

// Session lives in an HttpOnly cookie set by the API; JS only keeps the cached profile.
export function clearSession(): void {
  if (typeof window !== 'undefined') {
    localStorage.removeItem('admin_user');
  }
}

// Region codes are stored in char() columns, so the API returns them space-padded.
const trimCodes = (items: RegionItem[]): RegionItem[] => items.map((i) => ({ ...i, code: i.code.trim() }));

export async function apiRequest<T = any>(
  endpoint: string,
  options: RequestInit = {},
  timeoutMs = 15000
): Promise<T> {
  return (await apiRequestFull<T>(endpoint, options, timeoutMs)).data;
}

/** Like apiRequest, but resolves with the whole envelope (incl. pagination `meta`). */
export async function apiRequestFull<T = any>(
  endpoint: string,
  options: RequestInit = {},
  timeoutMs = 15000
): Promise<ApiResponse<T>> {
  const cleanEndpoint = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
  const url = `${API_BASE}${cleanEndpoint}`;

  const isFormData = typeof FormData !== 'undefined' && options.body instanceof FormData;
  const headers: Record<string, string> = {
    Accept: 'application/json',
    ...(isFormData ? {} : { 'Content-Type': 'application/json' }),
    ...(options.headers as Record<string, string>),
  };

  // Abort hung requests so the UI never sits on a loader forever.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  let response: Response;
  try {
    response = await fetch(url, {
      signal: controller.signal,
      ...options,
      credentials: 'include',
      headers,
    });
  } catch (err) {
    throw new ApiError(
      err instanceof DOMException && err.name === 'AbortError'
        ? 'Server tidak merespons. Coba lagi.'
        : 'Tidak dapat terhubung ke server.',
      undefined,
      0
    );
  } finally {
    clearTimeout(timer);
  }

  const data: ApiResponse<T> = await response.json().catch(() => ({
    success: false,
    message: 'Gagal memproses respon dari server.',
    data: null as any,
  }));

  if (!response.ok || !data.success) {
    if (response.status === 401 && typeof window !== 'undefined') {
      clearSession();
      if (!window.location.pathname.includes('/login')) {
        window.location.href = '/login';
      }
    }
    throw new ApiError(data.message || 'Terjadi kesalahan sistem.', data.errors, response.status);
  }

  return data;
}

/** Fetch a file from the API (with the session cookie) and save it in the browser. */
export async function apiDownload(endpoint: string, fileName: string): Promise<void> {
  let response: Response;
  try {
    response = await fetch(`${API_BASE}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`, {
      credentials: 'include',
      headers: { Accept: '*/*' },
    });
  } catch {
    throw new ApiError('Tidak dapat terhubung ke server.', undefined, 0);
  }

  if (!response.ok) {
    const data = await response.json().catch(() => null);
    throw new ApiError(data?.message || 'Gagal mengunduh file.', undefined, response.status);
  }

  const url = URL.createObjectURL(await response.blob());
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export const adminApi = {
  // Admin Auth (/api/admin/auth/*)
  async login(credentials: { email: string; password: string }): Promise<{ user: AdminUser }> {
    return apiRequest<{ user: AdminUser }>('/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });
  },

  async logout(): Promise<void> {
    try {
      await apiRequest('/admin/auth/logout', { method: 'POST' });
    } finally {
      clearSession();
    }
  },

  async getMe(): Promise<AdminUser> {
    return apiRequest<AdminUser>('/admin/auth/me');
  },

  async getSessions(): Promise<AdminSession[]> {
    return apiRequest<AdminSession[]>('/admin/auth/sessions');
  },

  async revokeSession(id: number): Promise<void> {
    await apiRequest(`/admin/auth/sessions/${id}`, { method: 'DELETE' });
  },

  async revokeOtherSessions(): Promise<{ revoked: number }> {
    return apiRequest<{ revoked: number }>('/admin/auth/sessions', { method: 'DELETE' });
  },

  // Roles (/api/admin/roles/*)
  async getRoles(): Promise<Role[]> {
    return apiRequest<Role[]>('/admin/roles');
  },

  async getAvailablePermissions(): Promise<PermissionGroups> {
    return apiRequest<PermissionGroups>('/admin/roles/permissions');
  },

  async createRole(data: { name: string; slug?: string; description?: string; permissions: string[] }): Promise<Role> {
    return apiRequest<Role>('/admin/roles', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  async updateRole(id: string, data: { name: string; description?: string; permissions: string[] }): Promise<Role> {
    return apiRequest<Role>(`/admin/roles/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  },

  async deleteRole(id: string): Promise<void> {
    return apiRequest<void>(`/admin/roles/${id}`, {
      method: 'DELETE',
    });
  },

  // Admin & Staff Users (/api/admin/staff/*)
  async getStaffUsers(params?: { search?: string; role_id?: string; page?: number }): Promise<PaginatedData<AdminUser>> {
    const query = new URLSearchParams();
    if (params?.search) query.append('search', params.search);
    if (params?.role_id) query.append('role_id', params.role_id);
    if (params?.page) query.append('page', params.page.toString());

    return apiRequest<PaginatedData<AdminUser>>(`/admin/staff?${query.toString()}`);
  },

  async createStaffUser(data: { name: string; email: string; phone?: string; password: string; role_id: string }): Promise<AdminUser> {
    return apiRequest<AdminUser>('/admin/staff', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  async updateStaffUser(id: string, data: { name: string; email: string; phone?: string; password?: string; role_id?: string; is_active?: boolean }): Promise<AdminUser> {
    return apiRequest<AdminUser>(`/admin/staff/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  },

  async deleteStaffUser(id: string): Promise<void> {
    return apiRequest<void>(`/admin/staff/${id}`, {
      method: 'DELETE',
    });
  },

  // Driver Management (/api/admin/drivers/*)
  async getDrivers(params?: { search?: string; is_active?: boolean; page?: number }): Promise<PaginatedData<Driver>> {
    const query = new URLSearchParams();
    if (params?.search) query.append('search', params.search);
    if (params?.is_active !== undefined) query.append('is_active', params.is_active ? '1' : '0');
    if (params?.page) query.append('page', params.page.toString());

    return apiRequest<PaginatedData<Driver>>(`/admin/drivers?${query.toString()}`);
  },

  async createDriver(data: {
    name: string;
    email: string;
    phone?: string;
    password: string;
    vehicle_type?: string;
    vehicle_plate_number?: string;
    is_active?: boolean;
  }): Promise<Driver> {
    return apiRequest<Driver>('/admin/drivers', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  async updateDriver(
    id: string,
    data: {
      name: string;
      email: string;
      phone?: string;
      password?: string;
      vehicle_type?: string;
      vehicle_plate_number?: string;
      is_active?: boolean;
    }
  ): Promise<Driver> {
    return apiRequest<Driver>(`/admin/drivers/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  },

  async setDriverStatus(id: string, is_active: boolean): Promise<Driver> {
    return apiRequest<Driver>(`/admin/drivers/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ is_active }),
    });
  },

  async deleteDriver(id: string): Promise<void> {
    return apiRequest<void>(`/admin/drivers/${id}`, {
      method: 'DELETE',
    });
  },

  async getDriverOrders(driverId: string, page = 1): Promise<PaginatedData<DriverOrder>> {
    return apiRequest<PaginatedData<DriverOrder>>(`/admin/drivers/${driverId}/orders?page=${page}`);
  },

  // Customers (/api/admin/customers/*)
  async getCustomers(params?: { search?: string; page?: number }): Promise<PaginatedData<Customer>> {
    const query = new URLSearchParams();
    if (params?.search) query.append('search', params.search);
    if (params?.page) query.append('page', params.page.toString());

    return apiRequest<PaginatedData<Customer>>(`/admin/customers?${query.toString()}`);
  },

  async createCustomer(data: { name: string; email: string; phone?: string; password: string }): Promise<Customer> {
    return apiRequest<Customer>('/admin/customers', {
      method: 'POST',
      body: JSON.stringify({ ...data, phone: data.phone || null }),
    });
  },

  async getCustomerDetail(id: string): Promise<CustomerDetail> {
    return apiRequest<CustomerDetail>(`/admin/customers/${id}`);
  },

  async revokeCustomerSession(id: string, sessionId: string): Promise<void> {
    await apiRequest(`/admin/customers/${id}/sessions/${encodeURIComponent(sessionId)}`, { method: 'DELETE' });
  },

  async blockCustomer(id: string, reason?: string): Promise<Customer> {
    return apiRequest<Customer>(`/admin/customers/${id}/block`, {
      method: 'POST',
      body: JSON.stringify({ reason: reason || null }),
    });
  },

  async banCustomer(id: string, features: string[], reason?: string): Promise<Customer> {
    return apiRequest<Customer>(`/admin/customers/${id}/ban`, {
      method: 'POST',
      body: JSON.stringify({ features, reason: reason || null }),
    });
  },

  async unbanCustomer(id: string): Promise<Customer> {
    return apiRequest<Customer>(`/admin/customers/${id}/unban`, { method: 'POST' });
  },

  async unblockCustomer(id: string): Promise<Customer> {
    return apiRequest<Customer>(`/admin/customers/${id}/unblock`, { method: 'POST' });
  },

  // Operational & Banners
  async getBanners(): Promise<Banner[]> {
    return apiRequest<Banner[]>('/admin/banners');
  },

  async createBanner(data: FormData | { name: string; image_url?: string; link_url?: string; is_active?: boolean }): Promise<Banner> {
    const isForm = typeof FormData !== 'undefined' && data instanceof FormData;
    return apiRequest<Banner>('/admin/banners', {
      method: 'POST',
      body: isForm ? data : JSON.stringify(data),
    });
  },

  async updateBanner(
    id: string,
    data: FormData | { name?: string; image_url?: string; link_url?: string; is_active?: boolean; sort_order?: number }
  ): Promise<Banner> {
    const isForm = typeof FormData !== 'undefined' && data instanceof FormData;
    return apiRequest<Banner>(`/admin/banners/${id}`, {
      method: 'POST',
      body: isForm ? data : JSON.stringify(data),
    });
  },

  async toggleBannerStatus(id: string): Promise<Banner> {
    return apiRequest<Banner>(`/admin/banners/${id}/toggle`, {
      method: 'POST',
    });
  },

  async reorderBanners(ids: string[]): Promise<void> {
    return apiRequest<void>('/admin/banners/reorder', {
      method: 'POST',
      body: JSON.stringify({ ids }),
    });
  },

  async deleteBanner(id: string): Promise<void> {
    return apiRequest<void>(`/admin/banners/${id}`, {
      method: 'DELETE',
    });
  },

  async getCategories(): Promise<any[]> {
    return apiRequest<any[]>('/admin/categories?per_page=200');
  },

  async getProducts(search = '', status = ''): Promise<any[]> {
    return apiRequest<any[]>(
      `/admin/products?per_page=100&search=${encodeURIComponent(search)}&status=${encodeURIComponent(status)}`
    );
  },

  async getProductStocks(search = '', warehouseId = ''): Promise<ProductStockRow[]> {
    return apiRequest<ProductStockRow[]>(
      `/admin/product-stocks?per_page=100&search=${encodeURIComponent(search)}&warehouse_id=${encodeURIComponent(warehouseId)}`
    );
  },

  async updateProductStock(
    id: string,
    stocks: { warehouse_id: string; quantity: number }[]
  ): Promise<ProductStockRow> {
    return apiRequest<ProductStockRow>(`/admin/product-stocks/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ stocks }),
    });
  },

  async getProduct(id: string): Promise<any> {
    return apiRequest<any>(`/admin/products/${id}`);
  },

  async uploadProductImages(id: string, files: File[]): Promise<any> {
    const body = new FormData();
    files.forEach((f) => body.append('images[]', f));
    return apiRequest<any>(`/admin/products/${id}/images`, { method: 'POST', body });
  },

  async setPrimaryProductImage(id: string, imageId: string): Promise<any> {
    return apiRequest<any>(`/admin/products/${id}/images/${imageId}/primary`, { method: 'POST' });
  },

  async deleteProductImage(id: string, imageId: string): Promise<any> {
    return apiRequest<any>(`/admin/products/${id}/images/${imageId}`, { method: 'DELETE' });
  },

  async createProduct(data: Record<string, any>): Promise<any> {
    return apiRequest<any>('/admin/products', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },

  async updateProduct(id: string, data: Record<string, any>): Promise<any> {
    return apiRequest<any>(`/admin/products/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  },

  async bulkUpdateProductStatus(ids: string[], status: string): Promise<any> {
    return apiRequest<any>('/admin/products/bulk-status', {
      method: 'POST',
      body: JSON.stringify({ ids, status }),
    });
  },

  async bulkDeleteProducts(ids: string[]): Promise<any> {
    return apiRequest<any>('/admin/products/bulk-delete', {
      method: 'POST',
      body: JSON.stringify({ ids }),
    });
  },

  async updateProductStatus(id: string, status: string): Promise<any> {
    return apiRequest<any>(`/admin/products/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
  },

  async toggleCategory(id: string): Promise<any> {
    return apiRequest<any>(`/admin/categories/${id}/toggle`, { method: 'POST' });
  },

  async deleteCategory(id: string): Promise<void> {
    return apiRequest<void>(`/admin/categories/${id}`, { method: 'DELETE' });
  },

  async reorderCategories(ids: string[]): Promise<void> {
    return apiRequest<void>('/admin/categories/reorder', {
      method: 'POST',
      body: JSON.stringify({ ids }),
    });
  },

  async saveCategory(data: FormData, id?: string): Promise<any> {
    return apiRequest<any>(id ? `/admin/categories/${id}` : '/admin/categories', {
      method: 'POST',
      body: data,
    });
  },

  async getSearchSuggestions(search = '', source = ''): Promise<SearchSuggestion[]> {
    return apiRequest<SearchSuggestion[]>(
      `/admin/search-suggestions?search=${encodeURIComponent(search)}&source=${encodeURIComponent(source)}`
    );
  },

  async createSearchSuggestion(keyword: string, searchCount: number): Promise<SearchSuggestion> {
    return apiRequest<SearchSuggestion>('/admin/search-suggestions', {
      method: 'POST',
      body: JSON.stringify({ keyword, search_count: searchCount }),
    });
  },

  async deleteSearchSuggestion(id: number): Promise<void> {
    return apiRequest<void>(`/admin/search-suggestions/${id}`, { method: 'DELETE' });
  },

  async getProductAttributes(): Promise<ProductAttribute[]> {
    return apiRequest<ProductAttribute[]>('/admin/product-attributes');
  },

  async saveProductAttribute(data: Partial<ProductAttribute>, id?: string): Promise<ProductAttribute> {
    return apiRequest<ProductAttribute>(id ? `/admin/product-attributes/${id}` : '/admin/product-attributes', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(data),
    });
  },

  async deleteProductAttribute(id: string): Promise<void> {
    return apiRequest<void>(`/admin/product-attributes/${id}`, { method: 'DELETE' });
  },

  async getRegionProvinces(): Promise<RegionItem[]> {
    return trimCodes(await apiRequest<RegionItem[]>('/v1/regions/provinces'));
  },

  async getRegionCities(provinceCode: string): Promise<RegionItem[]> {
    return trimCodes(await apiRequest<RegionItem[]>(`/v1/regions/provinces/${provinceCode}/cities`));
  },

  async getRegionDistricts(cityCode: string): Promise<RegionItem[]> {
    return trimCodes(await apiRequest<RegionItem[]>(`/v1/regions/cities/${cityCode}/districts`));
  },

  async getRegionVillages(districtCode: string): Promise<RegionItem[]> {
    return trimCodes(await apiRequest<RegionItem[]>(`/v1/regions/districts/${districtCode}/villages`));
  },

  async getWarehouses(): Promise<Warehouse[]> {
    return apiRequest<Warehouse[]>('/admin/warehouses');
  },

  async getWarehouse(id: string): Promise<Warehouse> {
    return apiRequest<Warehouse>(`/admin/warehouses/${id}`);
  },

  async saveWarehouse(data: Partial<Warehouse>, id?: string): Promise<Warehouse> {
    return apiRequest<Warehouse>(id ? `/admin/warehouses/${id}` : '/admin/warehouses', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(data),
    });
  },

  async deleteWarehouse(id: string): Promise<void> {
    return apiRequest<void>(`/admin/warehouses/${id}`, { method: 'DELETE' });
  },

  async getServiceCities(): Promise<ServiceCityOptions> {
    const data = await apiRequest<ServiceCityOptions>('/admin/service-cities');
    return {
      selected: data.selected.map((c) => c.trim()),
      provinces: data.provinces.map((p) => ({
        ...p,
        code: p.code.trim(),
        cities: trimCodes(p.cities),
      })),
    };
  },

  async saveServiceCities(cities: string[]): Promise<void> {
    return apiRequest<void>('/admin/service-cities', {
      method: 'PUT',
      body: JSON.stringify({ cities }),
    });
  },

  async getServiceFee(): Promise<ServiceFeeSettings> {
    return apiRequest<ServiceFeeSettings>('/admin/service-fee');
  },

  async saveServiceFee(payload: ServiceFeeSettings): Promise<ServiceFeeSettings> {
    return apiRequest<ServiceFeeSettings>('/admin/service-fee', {
      method: 'PUT',
      body: JSON.stringify(payload),
    });
  },

  async getWalletBonus(): Promise<WalletBonusSettings> {
    return apiRequest<WalletBonusSettings>('/admin/wallet-bonus');
  },

  async saveWalletBonus(payload: WalletBonusSettings): Promise<WalletBonusSettings> {
    return apiRequest<WalletBonusSettings>('/admin/wallet-bonus', {
      method: 'PUT',
      body: JSON.stringify(payload),
    });
  },

  async getNavBadge(): Promise<NavBadgeSettings> {
    return apiRequest<NavBadgeSettings>('/admin/nav-badge');
  },

  async saveNavBadge(payload: NavBadgeSettings): Promise<NavBadgeSettings> {
    return apiRequest<NavBadgeSettings>('/admin/nav-badge', {
      method: 'PUT',
      body: JSON.stringify(payload),
    });
  },

  async getShippingMethods(): Promise<ShippingMethod[]> {
    return apiRequest<ShippingMethod[]>('/admin/shipping-methods?per_page=100');
  },

  async saveShippingMethod(data: Partial<ShippingMethod>, id?: string): Promise<ShippingMethod> {
    return apiRequest<ShippingMethod>(id ? `/admin/shipping-methods/${id}` : '/admin/shipping-methods', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(data),
    });
  },

  async deleteShippingMethod(id: string): Promise<void> {
    return apiRequest<void>(`/admin/shipping-methods/${id}`, { method: 'DELETE' });
  },

  async toggleShippingMethod(id: string): Promise<ShippingMethod> {
    return apiRequest<ShippingMethod>(`/admin/shipping-methods/${id}/toggle`, { method: 'POST' });
  },

  async getDeliverySchedules(shippingMethodId: string): Promise<DeliverySchedule[]> {
    return apiRequest<DeliverySchedule[]>(
      `/admin/delivery-schedules?shipping_method_id=${encodeURIComponent(shippingMethodId)}`
    );
  },

  async getDeliveryHolidays(shippingMethodId?: string): Promise<DeliveryHoliday[]> {
    const q = shippingMethodId ? `?shipping_method_id=${encodeURIComponent(shippingMethodId)}` : '';
    return apiRequest<DeliveryHoliday[]>(`/admin/delivery-holidays${q}`);
  },

  async saveDeliveryHoliday(data: Partial<DeliveryHoliday>, id?: string): Promise<DeliveryHoliday> {
    return apiRequest<DeliveryHoliday>(id ? `/admin/delivery-holidays/${id}` : '/admin/delivery-holidays', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(data),
    });
  },

  async deleteDeliveryHoliday(id: string): Promise<void> {
    return apiRequest<void>(`/admin/delivery-holidays/${id}`, { method: 'DELETE' });
  },

  async saveDeliverySchedule(data: Partial<DeliverySchedule>, id?: string): Promise<DeliverySchedule> {
    return apiRequest<DeliverySchedule>(id ? `/admin/delivery-schedules/${id}` : '/admin/delivery-schedules', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(data),
    });
  },

  async deleteDeliverySchedule(id: string): Promise<void> {
    return apiRequest<void>(`/admin/delivery-schedules/${id}`, { method: 'DELETE' });
  },

  async getOrders(): Promise<PaginatedData<any>> {
    return apiRequest<PaginatedData<any>>('/admin/orders');
  },

  async getFlashSales(params: { search?: string; status?: string; page?: number } = {}): Promise<ApiResponse<FlashSale[]>> {
    const query = new URLSearchParams();
    if (params.search) query.append('search', params.search);
    if (params.status) query.append('status', params.status);
    if (params.page) query.append('page', params.page.toString());
    return apiRequestFull<FlashSale[]>(`/admin/flash-sales?${query.toString()}`);
  },

  async getFlashSale(id: string): Promise<FlashSale> {
    return apiRequest<FlashSale>(`/admin/flash-sales/${id}`);
  },

  async saveFlashSale(data: FlashSalePayload, id?: string): Promise<FlashSale> {
    return apiRequest<FlashSale>(id ? `/admin/flash-sales/${id}` : '/admin/flash-sales', {
      method: id ? 'PUT' : 'POST',
      body: JSON.stringify(data),
    });
  },

  async toggleFlashSale(id: string): Promise<FlashSale> {
    return apiRequest<FlashSale>(`/admin/flash-sales/${id}/toggle`, { method: 'POST' });
  },

  async deleteFlashSale(id: string): Promise<void> {
    return apiRequest<void>(`/admin/flash-sales/${id}`, { method: 'DELETE' });
  },
};
