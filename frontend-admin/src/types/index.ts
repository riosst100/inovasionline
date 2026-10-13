export interface Role {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  permissions: string[];
  is_system: boolean;
  users_count?: number;
  created_at: string;
  updated_at: string;
}

export interface AdminUser {
  id: string;
  name: string;
  email: string;
  phone: string | null;
  vehicle_type?: string | null;
  vehicle_plate_number?: string | null;
  delivered_orders_count?: number;
  avatar_url: string | null;
  is_active: boolean;
  role_id: string;
  is_super_admin: boolean;
  role: {
    id: string;
    name: string;
    slug: string;
    description: string | null;
    permissions: string[];
  } | null;
  created_at: string;
  updated_at: string;
}

export interface Driver {
  id: string;
  name: string;
  email: string;
  phone: string | null;
  vehicle_type: string | null;
  vehicle_plate_number: string | null;
  avatar_url: string | null;
  is_active: boolean;
  delivered_orders_count: number;
  role_id: string;
  created_at: string;
  updated_at: string;
}

export interface DriverOrder {
  id: string;
  order_number: string;
  customer_name: string;
  customer_phone: string;
  delivery_address: string;
  status: string;
  payment_status: string;
  grand_total: number;
  total_items: number;
  created_at: string;
  completed_at: string | null;
}

export interface Customer {
  id: string;
  name: string;
  email: string;
  phone: string | null;
  role: string;
  avatar_url: string | null;
  is_seller: boolean;
  is_verified: boolean;
  created_at: string;
}

export interface PermissionItem {
  key: string;
  label: string;
}

export interface PermissionGroup {
  title: string;
  items: PermissionItem[];
}

export type PermissionGroups = Record<string, PermissionGroup>;

export interface ApiResponse<T = any> {
  success: boolean;
  message: string;
  data: T;
  errors?: Record<string, string[]>;
}

export interface PaginatedData<T> {
  data: T[];
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
}

export interface Banner {
  id: string;
  name: string;
  image_url: string;
  link_url: string | null;
  is_active: boolean;
  sort_order: number;
  created_at?: string;
  updated_at?: string;
}
