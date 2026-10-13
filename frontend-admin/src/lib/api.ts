import { ApiResponse, Role, AdminUser, Driver, DriverOrder, Customer, PermissionGroups, PaginatedData, Banner } from '../types';

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

function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('admin_token');
}

export function setToken(token: string): void {
  if (typeof window !== 'undefined') {
    localStorage.setItem('admin_token', token);
  }
}

export function removeToken(): void {
  if (typeof window !== 'undefined') {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
  }
}

export async function apiRequest<T = any>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = getToken();
  const cleanEndpoint = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
  const url = `${API_BASE}${cleanEndpoint}`;

  const isFormData = typeof FormData !== 'undefined' && options.body instanceof FormData;
  const headers: Record<string, string> = {
    Accept: 'application/json',
    ...(isFormData ? {} : { 'Content-Type': 'application/json' }),
    ...(options.headers as Record<string, string>),
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });

  const data: ApiResponse<T> = await response.json().catch(() => ({
    success: false,
    message: 'Gagal memproses respon dari server.',
    data: null as any,
  }));

  if (!response.ok || !data.success) {
    if (response.status === 401 && typeof window !== 'undefined') {
      removeToken();
      if (!window.location.pathname.includes('/login')) {
        window.location.href = '/login';
      }
    }
    throw new ApiError(data.message || 'Terjadi kesalahan sistem.', data.errors, response.status);
  }

  return data.data;
}

export const adminApi = {
  // Admin Auth (/api/admin/auth/*)
  async login(credentials: { email: string; password: string }): Promise<{ user: AdminUser; token: string }> {
    return apiRequest<{ user: AdminUser; token: string }>('/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });
  },

  async logout(): Promise<void> {
    try {
      await apiRequest('/admin/auth/logout', { method: 'POST' });
    } finally {
      removeToken();
    }
  },

  async getMe(): Promise<AdminUser> {
    return apiRequest<AdminUser>('/admin/auth/me');
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
    return apiRequest<any[]>('/admin/categories');
  },

  async getOrders(): Promise<PaginatedData<any>> {
    return apiRequest<PaginatedData<any>>('/admin/orders');
  },
};
