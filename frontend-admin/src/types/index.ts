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

export type BannableFeature = 'chat' | 'posts' | 'purchase';

export interface Customer {
  id: string;
  name: string;
  email: string;
  phone: string | null;
  role: string;
  avatar_url: string | null;
  is_seller: boolean;
  is_verified: boolean;
  is_blocked: boolean;
  blocked_at: string | null;
  block_reason: string | null;
  banned_features: BannableFeature[];
  ban_reason: string | null;
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

export interface AdminSession {
  id: number;
  device: string;
  ip_address: string | null;
  user_agent: string | null;
  last_active_at: string | null;
  created_at: string | null;
  expires_at: string | null;
  is_current: boolean;
}

export interface SearchSuggestion {
  id: number;
  keyword: string;
  search_count: number;
  source: 'user' | 'admin';
  last_searched_at: string | null;
  created_at: string | null;
}

export type ProductAttributeType = 'text' | 'textarea' | 'number' | 'boolean' | 'select' | 'date';

export interface ProductAttribute {
  id: string;
  code: string;
  name: string;
  type: ProductAttributeType;
  options: string[] | null;
  description: string | null;
  is_system: boolean;
  is_required: boolean;
  is_active: boolean;
  sort_order: number;
}

export interface Warehouse {
  id: string;
  code: string;
  name: string;
  address: string | null;
  city: string | null;
  province: string | null;
  postal_code: string | null;
  latitude: number | null;
  longitude: number | null;
  contact_name: string | null;
  contact_phone: string | null;
  notes: string | null;
  is_active: boolean;
  coverage?: WarehouseCoverage[];
}

export interface ProductStockRow {
  id: string;
  name: string;
  sku: string | null;
  min_stock: number;
  image_url: string | null;
  total: number;
  stocks: { warehouse_id: string; warehouse_code: string; warehouse_name: string; quantity: number }[];
}

export interface RegionItem {
  code: string;
  name: string;
}

export interface WarehouseCoverage {
  district_code: string;
  district_name: string;
  /** null = seluruh desa di kecamatan tersebut */
  village_code: string | null;
  village_name: string | null;
}

export interface ServiceFeeSettings {
  is_active: boolean;
  label: string;
  type: 'fixed' | 'percent';
  value: number;
  min_fee: number | null;
  max_fee: number | null;
}

export interface ServiceCityOptions {
  /** Kode kota yang dijangkau aplikasi */
  selected: string[];
  provinces: { code: string; name: string; cities: RegionItem[] }[];
}
