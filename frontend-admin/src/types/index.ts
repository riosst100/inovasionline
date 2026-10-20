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
  is_verified: boolean;
  is_blocked: boolean;
  blocked_at: string | null;
  block_reason: string | null;
  banned_features: BannableFeature[];
  ban_reason: string | null;
  created_at: string;
}

export type LoginMethod = 'password' | 'google' | 'register';

export interface CustomerDetail {
  customer: Customer & {
    gender: string | null;
    date_of_birth: string | null;
    address_label: string | null;
    wallet_balance: string | number | null;
    email_verified_at: string | null;
    phone_verified_at: string | null;
  };
  login: {
    has_password: boolean;
    google_linked: boolean;
    email_verified_at: string | null;
    phone_verified_at: string | null;
    last_login_at: string | null;
    last_login_ip: string | null;
    last_login_method: LoginMethod | null;
    login_count: number;
    active_session_count: number;
  };
  sessions: {
    id: string;
    type: 'token' | 'web';
    device: string;
    ip_address: string | null;
    user_agent: string | null;
    last_active_at: string | null;
    created_at: string | null;
    expires_at: string | null;
  }[];
  push_devices: {
    id: string;
    platform: string;
    token_preview: string;
    registered_at: string | null;
    updated_at: string | null;
  }[];
  ip_addresses: {
    ip_address: string;
    login_count: number;
    active_sessions: number;
    first_seen_at: string | null;
    last_seen_at: string | null;
  }[];
  login_history: {
    id: number;
    method: LoginMethod;
    client: 'mobile' | 'web';
    device: string | null;
    ip_address: string | null;
    user_agent: string | null;
    created_at: string | null;
  }[];
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
  meta?: PaginationMeta;
}

export interface PaginationMeta {
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
}

export type DataTransferType = 'import' | 'export';
export type DataTransferFormat = 'csv' | 'xlsx';
export type DataTransferStatus = 'pending' | 'processing' | 'completed' | 'failed';

/** Queued CSV/XLSX import or export (`/api/admin/data-transfers`). */
export interface DataTransfer {
  id: string;
  type: DataTransferType;
  /** Resource key, e.g. "categories", "products" */
  resource: string;
  format: DataTransferFormat;
  status: DataTransferStatus;
  file_name: string | null;
  has_file: boolean;
  total_rows: number;
  processed_rows: number;
  created_rows: number;
  updated_rows: number;
  failed_rows: number;
  /** 0-100 */
  progress: number;
  /** Only present on the detail endpoint */
  row_errors?: { row: number; message: string }[];
  error_message: string | null;
  admin_user?: { id: string; name: string } | null;
  started_at: string | null;
  finished_at: string | null;
  created_at: string;
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

export interface ShippingMethod {
  id: string;
  type: string;
  name: string;
  description: string | null;
  base_fee: number;
  estimated_delivery_time: string | null;
  free_shipping_min_amount: number | null;
  /** Pembeli wajib memilih jadwal pengiriman saat checkout */
  requires_schedule: boolean;
  /** Bisa dipesan untuk hari ini s.d. (n - 1) hari ke depan */
  schedule_days_ahead: number;
  delivery_schedules_count?: number;
  is_enabled: boolean;
  sort_order: number;
}

export interface DeliveryHoliday {
  id: string;
  /** null = berlaku untuk semua metode pengiriman */
  shipping_method_id: string | null;
  shipping_method_name: string | null;
  /** Y-m-d */
  date: string;
  name: string;
}

export interface DeliverySchedule {
  id: string;
  shipping_method_id: string;
  label: string;
  /** HH:MM, waktu lokal (WIB) */
  start_time: string;
  end_time: string;
  /** Pemesanan ditutup sekian menit sebelum jam mulai */
  cutoff_minutes: number;
  /** Maks. pesanan per hari; null = tanpa batas */
  quota: number | null;
  /** Hari ISO (1 = Senin … 7 = Minggu); null = setiap hari */
  days: number[] | null;
  is_active: boolean;
  sort_order: number;
}

export interface WalletBonusTier {
  from: number;
  to: number;
  /** Chance of this range, in % (all tiers add up to 100). */
  weight: number;
}

export interface WalletBonusSettings {
  is_active: boolean;
  /** Amounts are rolled in multiples of this. */
  step: number;
  tiers: WalletBonusTier[];
}

/** Iklan > Peti Hadiah: rewarded ads fill a chest that pays random saldo belanja. */
export interface AdChestSettings {
  is_active: boolean;
  chests_per_day: number;
  /** Saldo all chests may pay out per day (WIB); 0 = no cap. */
  daily_budget: number;
  step: number;
  tiers: WalletBonusTier[];
  /** Read-only: AdMob is on with a rewarded unit, without which the chest never shows. */
  ads_ready?: boolean;
  /** Read-only: saldo paid out by chests today. */
  paid_today?: number;
}

export interface ServiceFeeSettings {
  is_active: boolean;
  label: string;
  type: 'fixed' | 'percent';
  value: number;
  min_fee: number | null;
  max_fee: number | null;
}

export interface WalletRow {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  balance: number;
}

export interface WalletTransactionRow {
  id: string;
  type: 'topup' | 'payment' | 'refund' | 'adjustment' | 'bonus' | 'ad_chest';
  /** Signed: + credit, - debit */
  amount: number;
  balance_after: number;
  description: string;
  order_id: string | null;
  admin?: { id: string; name: string } | null;
  created_at: string;
}

export type WalletTopupStatus = 'pending' | 'paid' | 'failed' | 'expired';

export interface WalletTopupRow {
  id: string;
  topup_number: string;
  amount: number;
  status: WalletTopupStatus;
  /** e.g. "Virtual Account BCA"; null until the customer picks a channel */
  payment_method: string | null;
  payment_expires_at: string | null;
  paid_at: string | null;
  created_at: string;
  user: { id: string; name: string; email: string | null; phone: string | null } | null;
}

export interface WalletTopupDetail extends Omit<WalletTopupRow, 'user'> {
  payment_type: string | null;
  /** VA number, bill key, payment code, masked card, … as shown to the payer */
  payment_fields: { label: string; value: string }[];
  payment_redirect_url: string | null;
  updated_at: string;
  balance_after: number | null;
  user: { id: string; name: string; email: string | null; phone: string | null; balance: number } | null;
}

export type WalletTopupSummary = Record<WalletTopupStatus, { count: number; total: number }>;

export interface WalletReportTransaction {
  id: string;
  type: WalletTransactionRow['type'];
  /** Signed: + pemasukan, - pengeluaran */
  amount: number;
  balance_after: number;
  description: string;
  payment_method: string | null;
  topup: { id: string; topup_number: string } | null;
  order: { id: string; order_number: string } | null;
  admin: { id: string; name: string } | null;
  user: { id: string; name: string; email: string | null; phone: string | null } | null;
  created_at: string;
}

export interface WalletReport {
  total_balance: number;
  customers_with_balance: number;
  period: {
    opening_balance: number;
    total_in: number;
    total_out: number;
    net: number;
    closing_balance: number;
  };
  income_by_type: { type: WalletTransactionRow['type']; total: number }[];
  expense_by_type: { type: WalletTransactionRow['type']; total: number }[];
  income_by_method: { method: string; total: number; count: number }[];
  transactions: WalletReportTransaction[];
}

export interface WalletDetail {
  user: { id: string; name: string; email: string | null; phone: string | null };
  balance: number;
  transactions: WalletTransactionRow[];
}

export interface OrderSettings {
  /** How long a buyer may still cancel once the order is being prepared; 0 = not at all */
  buyer_cancel_window_seconds: number;
  /** Completed orders a customer needs before Paylater unlocks */
  paylater_min_transactions: number;
  /** Days a customer has to settle a Paylater order */
  paylater_due_days: number;
}

export interface NavBadgeSettings {
  is_active: boolean;
  label: string;
  /** ISO 8601, null = no limit */
  starts_at: string | null;
  ends_at: string | null;
  /** Read-only: active and inside the schedule right now */
  is_visible?: boolean;
}

export interface AdmobSettings {
  is_active: boolean;
  android_banner_id: string | null;
  ios_banner_id: string | null;
  android_interstitial_id: string | null;
  ios_interstitial_id: string | null;
  android_rewarded_id: string | null;
  ios_rewarded_id: string | null;
  home_banner: boolean;
  home_bottom_banner: boolean;
  product_list_banner: boolean;
  product_detail_banner: boolean;
  interstitial_enabled: boolean;
  /** Interstitial on every Nth product detail opened */
  interstitial_every: number;
  /** The one-time saldo bonus is claimable only after a fully watched rewarded ad */
  bonus_requires_ad: boolean;
  android_native_id: string | null;
  ios_native_id: string | null;
  /** Native ad after every Nth post in the Posts feed; 0 = off */
  posts_native_every: number;
  /** Read-only: paste into the rewarded ad unit's server-side verification setting */
  ssv_callback_url?: string;
}

export interface ServiceCityOptions {
  /** Kode kota yang dijangkau aplikasi */
  selected: string[];
  provinces: { code: string; name: string; cities: RegionItem[] }[];
}

export type FlashSaleStatus = 'running' | 'upcoming' | 'ended' | 'inactive';

export interface FlashSaleProduct {
  product_id: string;
  name: string;
  sku: string | null;
  image_url: string | null;
  regular_price: number;
  sale_price: number | null;
  flash_sale_price: number | null;
}

export interface FlashSale {
  id: string;
  name: string;
  /** ISO 8601 */
  starts_at: string;
  ends_at: string;
  is_active: boolean;
  status: FlashSaleStatus;
  products_count?: number;
  products?: FlashSaleProduct[];
}

export interface FlashSalePayload {
  name: string;
  starts_at: string;
  ends_at: string;
  is_active: boolean;
  products: { product_id: string; flash_sale_price: number }[];
}

export type CodVerificationStatus = 'verified' | 'revoked';

export interface CodVerificationRow {
  id: string;
  user_id: string;
  video_url: string;
  steps: string[];
  device: string | null;
  ip_address: string | null;
  status: CodVerificationStatus;
  revoked_reason: string | null;
  revoked_at: string | null;
  created_at: string;
  user: { id: string; name: string; email: string | null; phone: string | null } | null;
}
