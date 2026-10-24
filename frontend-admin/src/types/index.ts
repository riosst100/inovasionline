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
  username: string;
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
  /** Face verification (COD/Paylater). null = never verified */
  verification_status: CodVerificationStatus | null;
  /** The verification event behind verification_status (verified by it, or revoked on it) */
  verification_id: string | null;
  /** Latest app heartbeat or API use; sent by the admin customer list/detail only */
  last_seen_at?: string | null;
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
  /** `summary`: optional endpoint-specific totals sent next to pagination (e.g. supplier bills) */
  meta?: PaginationMeta & { summary?: unknown };
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

export interface Supplier {
  id: string;
  name: string;
  contact_name: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  notes: string | null;
  is_active: boolean;
  products_count?: number;
}

export interface Brand {
  id: string;
  name: string;
  description: string | null;
  is_active: boolean;
  products_count?: number;
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

/** Promosi > Gratis Ongkir: free shipping when payment AND shipping method both qualify. */
export interface FreeShippingSettings {
  is_active: boolean;
  /** Minimal belanja (Rp); null = tanpa minimal */
  min_subtotal: number | null;
  payment_method_ids: string[];
  shipping_method_ids: string[];
}

export interface PaymentMethodOption {
  id: string;
  name: string;
  type: string;
  is_enabled: boolean;
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

export interface SalesSummary {
  revenue: number;
  revenue_paid: number;
  orders: number;
  average_order: number;
  items_sold: number;
  /** Goods sold after order discounts (no shipping/service fee) */
  product_sales: number;
  cost: number;
  gross_profit: number;
  /** Gross profit as a percentage of product_sales */
  margin: number;
  /** Units sold whose product has no cost price yet; their cost counts as 0 */
  items_without_cost: number;
  buyers: number;
  discount: number;
  shipping: number;
  completed: number;
  cancelled: number;
  new_customers: number;
}

export interface SalesReport {
  period: { date_from: string; date_to: string; days: number; summary: SalesSummary };
  previous: { date_from: string; date_to: string; summary: SalesSummary };
  granularity: 'hour' | 'day';
  series: { label: string; revenue: number; orders: number; previous_revenue: number; previous_orders: number }[];
  by_status: { status: string; orders: number; revenue: number }[];
  by_payment_method: { method: string; orders: number; revenue: number }[];
  top_products: { product_id: string | null; name: string; sold: number; revenue: number; profit: number | null }[];
  recent_orders: {
    id: string;
    order_number: string;
    customer: string | null;
    grand_total: number;
    status: string;
    payment_status: string | null;
    created_at: string;
  }[];
  overall: {
    revenue_total: number;
    orders_total: number;
    profit_total: number;
    revenue_this_month: number;
    orders_this_month: number;
    profit_this_month: number;
    open_orders: number;
    awaiting_payment: number;
  };
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

// Keuangan

export interface FinancePeriod {
  date_from: string;
  date_to: string;
  days: number;
}

export interface ProfitTotals {
  product_sales: number;
  discount: number;
  net_sales: number;
  cost: number;
  gross_profit: number;
  margin: number;
  items_sold: number;
  items_without_cost: number;
}

export interface FinanceReport {
  period: FinancePeriod;
  income_statement: ProfitTotals & {
    shipping: number;
    service_fee: number;
    gross_income: number;
    other_income: number;
    operating_expenses: number;
    net_income: number;
  };
  sales: { orders: number; total: number; tax: number; paid: number; unpaid: number; refunded: number };
  by_payment_method: { method: string; orders: number; total: number; paid: number }[];
  wallet: { topup: number; spent: number; other_credit: number; total_balance: number };
  supplier_bills: { billed: number; paid: number; outstanding: number; overdue: number };
}

export type ProfitGroup = 'product' | 'category' | 'supplier' | 'brand';

export interface ProfitReport {
  period: FinancePeriod;
  group: ProfitGroup;
  totals: ProfitTotals;
  rows: {
    id: string | null;
    name: string;
    quantity: number;
    revenue: number;
    /** null while some units sold have no cost */
    cost: number | null;
    profit: number | null;
    margin: number | null;
  }[];
  row_limit: number;
}

export type SupplierBillStatus = 'unpaid' | 'overdue' | 'paid';

export interface SupplierBill {
  id: string;
  supplier_id: string;
  supplier_name: string | null;
  bill_number: string;
  bill_date: string;
  due_date: string | null;
  amount: number;
  notes: string | null;
  status: SupplierBillStatus;
  paid_at: string | null;
  payment_notes: string | null;
  created_at: string;
}

export interface SupplierBillSummary {
  outstanding: number;
  outstanding_count: number;
  overdue: number;
  overdue_count: number;
  due_soon: number;
  due_soon_count: number;
  due_soon_days: number;
  paid_this_month: number;
}

export type SalaryType = 'per_order' | 'monthly' | 'per_delivery';

export interface Employee {
  id: string;
  name: string;
  phone: string | null;
  position: string;
  salary_type: SalaryType;
  /** Paid per salary_type unit */
  salary_amount: string | number;
  is_active: boolean;
  notes: string | null;
}

export interface EmployeeList {
  items: Employee[];
  positions: string[];
  summary: { active: number; monthly_total: number };
}

export type CashType = 'income' | 'expense';
export type CashSource = 'order' | 'supplier_bill' | 'manual';

export interface CashEntry {
  source: CashSource;
  /** Order, supplier bill or company transaction id, depending on source */
  id: string;
  type: CashType;
  category: string;
  amount: number;
  date: string;
  description: string | null;
  /** Order number or bill number */
  reference: string | null;
  employee_id: string | null;
  employee_name: string | null;
}

export interface CashBook {
  period: { date_from: string; date_to: string };
  summary: { income: number; expense: number; net: number };
  by_category: { type: CashType; category: string; total: number; count: number }[];
  categories: Record<CashType, string[]>;
  entries: CashEntry[];
}
