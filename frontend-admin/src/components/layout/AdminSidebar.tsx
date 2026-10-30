'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '../../context/AuthContext';
import { useInstantOrders } from '../../lib/instantOrders';
import {
  Bell,
  LayoutDashboard,
  ShieldCheck,
  UserCog,
  Info,
  Users2,
  Image as ImageIcon,
  SquareStack,
  LayoutTemplate,
  FolderTree,
  ShoppingBag,
  ListChecks,
  Truck,
  Package,
  Warehouse,
  PackageSearch,
  SlidersHorizontal,
  ChevronDown,
  MonitorSmartphone,
  TextSearch,
  Settings,
  MapPinned,
  Receipt,
  CreditCard,
  Tag,
  Smartphone,
  Wallet,
  Coins,
  ArrowUpCircle,
  FileBarChart,
  ScanFace,
  ArrowDownUp,
  Bike,
  CalendarClock,
  PackageCheck,
  Megaphone,
  Timer,
  Ticket,
  Percent,
  Zap,
  Gift,
  BadgeDollarSign,
  PackageOpen,
  Award,
  Building2,
  Database,
  IdCard,
  Landmark,
  ReceiptText,
  Scale,
  Code,
  X,
  RefreshCw,
} from 'lucide-react';

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

type NavLink = { name: string; href: string; icon: React.ElementType; perm?: string };

type NavItem = NavLink & {
  badge?: string;
  children?: NavLink[];
};

type NavSection = { title: string; items: NavItem[] };

/** `perm` is the menu key in the backend's AdminMenu; its view permission shows the link and opens the page. */
export const NAV_SECTIONS: NavSection[] = [
  {
    title: 'Utama',
    items: [
      { name: 'Ringkasan Dashboard', href: '/dashboard', icon: LayoutDashboard, perm: 'dashboard' },
      { name: 'Pesanan', href: '/dashboard/orders', icon: ShoppingBag, perm: 'orders' },
      { name: 'Jadwal Pengiriman', href: '/dashboard/delivery-schedules', icon: CalendarClock, perm: 'delivery_schedules' },
      { name: 'Verifikasi Pengguna', href: '/dashboard/cod-verifications', icon: ScanFace, perm: 'cod_verifications' },
    ],
  },
  {
    title: 'Operasional',
    items: [
      { name: 'Pengguna', href: '/dashboard/customers', icon: Users2, perm: 'customers' },
      { name: 'Kirim Notifikasi', href: '/dashboard/notifications', icon: Bell, perm: 'notifications' },
      {
        name: 'Saldo Belanja',
        href: '/dashboard/wallet',
        icon: Wallet,
        children: [
          { name: 'Saldo Pengguna', href: '/dashboard/wallets', icon: Coins, perm: 'wallets' },
          { name: 'Top Up Saldo', href: '/dashboard/wallet-topups', icon: ArrowUpCircle, perm: 'wallet_topups' },
        ],
      },
      {
        name: 'Master Data',
        href: '/dashboard/master-data',
        icon: Database,
        children: [
          { name: 'Produk', href: '/dashboard/products', icon: Package, perm: 'products' },
          { name: 'Kategori', href: '/dashboard/categories', icon: FolderTree, perm: 'categories' },
          { name: 'Atribut Produk', href: '/dashboard/attributes', icon: SlidersHorizontal, perm: 'attributes' },
          { name: 'Supplier', href: '/dashboard/master-data/suppliers', icon: Building2, perm: 'suppliers' },
          { name: 'Brand', href: '/dashboard/master-data/brands', icon: Award, perm: 'brands' },
          { name: 'Gudang', href: '/dashboard/warehouses', icon: Warehouse, perm: 'warehouses' },
          { name: 'Kurir', href: '/dashboard/drivers', icon: Bike, perm: 'drivers' },
        ],
      },
      {
        name: 'Laporan',
        href: '/dashboard/reports',
        icon: FileBarChart,
        children: [
          { name: 'Stok Produk', href: '/dashboard/product-stocks', icon: PackageSearch, perm: 'product_stocks' },
          { name: 'Kueri Pencarian', href: '/dashboard/search/suggestions', icon: TextSearch, perm: 'search_suggestions' },
          { name: 'Laporan Saldo Belanja', href: '/dashboard/wallet-report', icon: Wallet, perm: 'wallet_report' },
        ],
      },
      {
        name: 'Tampilan',
        href: '/dashboard/display',
        icon: LayoutTemplate,
        children: [
          { name: 'Banner', href: '/dashboard/banners', icon: ImageIcon, perm: 'banners' },
          { name: 'Popup Beranda', href: '/dashboard/popups', icon: SquareStack, perm: 'banners' },
          { name: 'Tulisan Promosi', href: '/dashboard/display/promo-texts', icon: Info, perm: 'promo_texts' },
        ],
      },
      {
        name: 'Promosi',
        href: '/dashboard/promotions',
        icon: Megaphone,
        children: [
          { name: 'Voucher', href: '/dashboard/promotions/vouchers', icon: Ticket, perm: 'vouchers' },
          { name: 'Diskon', href: '/dashboard/promotions/discounts', icon: Percent, perm: 'discounts' },
          { name: 'Flash Sale', href: '/dashboard/promotions/flash-sales', icon: Zap, perm: 'flash_sales' },
          { name: 'Gratis Ongkir', href: '/dashboard/promotions/free-shipping', icon: Truck, perm: 'free_shipping' },
          { name: 'Bonus Saldo Belanja', href: '/dashboard/promotions/wallet-bonus', icon: Gift, perm: 'wallet_bonus' },
        ],
      },
      {
        name: 'Iklan',
        href: '/dashboard/ads',
        icon: BadgeDollarSign,
        children: [
          { name: 'Iklan Produk', href: '/dashboard/ads/products', icon: PackageOpen, perm: 'product_ads' },
          { name: 'Adsense / Admob', href: '/dashboard/ads/adsense', icon: Code, perm: 'admob' },
          { name: 'Peti Hadiah', href: '/dashboard/ads/reward-chest', icon: Gift, perm: 'reward_chest' },
        ],
      },
      {
        name: 'Pengaturan',
        href: '/dashboard/settings',
        icon: Settings,
        children: [
          { name: 'Cakupan Kota', href: '/dashboard/settings/service-cities', icon: MapPinned, perm: 'service_cities' },
          { name: 'Biaya Layanan', href: '/dashboard/settings/service-fee', icon: Receipt, perm: 'service_fee' },
          { name: 'Payment Gateway', href: '/dashboard/settings/payment-gateway', icon: CreditCard, perm: 'payment_gateway' },
          { name: 'Bank & E-Wallet', href: '/dashboard/settings/bank-accounts', icon: Landmark, perm: 'bank_accounts' },
          { name: 'Badge Menu', href: '/dashboard/settings/nav-badge', icon: Tag, perm: 'nav_badge' },
          { name: 'Update Aplikasi', href: '/dashboard/settings/app-update', icon: Smartphone, perm: 'app_update' },
          { name: 'Cache Aplikasi', href: '/dashboard/settings/app-cache', icon: RefreshCw, perm: 'app_cache' },
          { name: 'Status Pesanan', href: '/dashboard/order-statuses', icon: ListChecks, perm: 'order_statuses' },
          { name: 'Metode Pengiriman', href: '/dashboard/shipping-methods', icon: PackageCheck, perm: 'shipping_methods' },
          { name: 'Pembatalan Pesanan', href: '/dashboard/settings/order-cancellation', icon: Timer, perm: 'order_cancellation' },
        ],
      },
    ],
  },
  {
    title: 'Perusahaan',
    items: [
      { name: 'Karyawan', href: '/dashboard/employees', icon: IdCard, perm: 'employees' },
      { name: 'Pembelian', href: '/dashboard/finance/bills', icon: ReceiptText, perm: 'purchases' },
      {
        name: 'Keuangan',
        href: '/dashboard/finance',
        icon: Landmark,
        children: [
          { name: 'Cashflow', href: '/dashboard/finance/cashflow', icon: Scale, perm: 'cashflow' },
          { name: 'Laporan Keuangan', href: '/dashboard/finance/report', icon: FileBarChart, perm: 'finance_report' },
        ],
      },
    ],
  },
  {
    title: 'Admin',
    items: [
      { name: 'User', href: '/dashboard/users', icon: UserCog, perm: 'users' },
      { name: 'Hak Akses & Role', href: '/dashboard/roles', icon: ShieldCheck, perm: 'roles' },
      { name: 'Sesi & Perangkat', href: '/dashboard/sessions', icon: MonitorSmartphone },
    ],
  },
  {
    title: 'Data',
    items: [{ name: 'Import / Export', href: '/dashboard/data-transfers', icon: ArrowDownUp, perm: 'data_transfers' }],
  },
];

const isLinkActive = (pathname: string, href: string) =>
  href === '/dashboard' ? pathname === href : pathname === href || pathname.startsWith(`${href}/`);

const NAV_LINKS: NavLink[] = NAV_SECTIONS.flatMap((s) => s.items.flatMap((i) => i.children ?? [i]));

/** Menu key guarding a dashboard URL (most specific link wins), or null when the page needs no menu permission. */
export function menuForPath(pathname: string): string | null {
  const match = NAV_LINKS.filter((l) => l.perm && isLinkActive(pathname, l.href)).sort(
    (a, b) => b.href.length - a.href.length,
  )[0];
  return match?.perm ?? null;
}

/** Sidebar URL of a menu key. */
export function hrefForMenu(menu: string): string | null {
  return NAV_LINKS.find((l) => l.perm === menu)?.href ?? null;
}

/** First page the user may open, used when they land on one they can't. */
export function firstAllowedHref(canView: (menu: string) => boolean): string | null {
  return NAV_LINKS.find((l) => l.perm && canView(l.perm))?.href ?? null;
}

/** Live count of unfinished orders on the Pesanan link (only rendered for roles that see Pesanan). */
function OpenOrdersBadge() {
  const { queue } = useInstantOrders();
  if (!queue || queue.open === 0) return null;
  const urgent = queue.unpacked > 0;

  return (
    <span
      title={`${queue.open} pesanan belum selesai`}
      className={`min-w-5 rounded-full px-1.5 py-0.5 text-center text-[10px] font-bold tabular-nums ${
        urgent ? 'animate-pulse bg-rose-500 text-white' : 'bg-amber-400 text-slate-950'
      }`}
    >
      {queue.open > 99 ? '99+' : queue.open}
    </span>
  );
}

function visibleSections(canView: (menu: string) => boolean): NavSection[] {
  const allowed = (l: NavLink) => !l.perm || canView(l.perm);
  return NAV_SECTIONS.map((section) => ({
    ...section,
    items: section.items
      .map((item) => (item.children ? { ...item, children: item.children.filter(allowed) } : item))
      .filter((item) => (item.children ? item.children.length > 0 : allowed(item))),
  })).filter((section) => section.items.length > 0);
}

export default function AdminSidebar({ isOpen, onClose }: SidebarProps) {
  const pathname = usePathname();
  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>({});
  const { canView } = useAuth();
  const sections = visibleSections(canView);

  return (
    <>
      {/* Mobile backdrop */}
      {isOpen && (
        <div
          onClick={onClose}
          className="animate-fade-in fixed inset-0 z-40 bg-slate-950/60 backdrop-blur-sm lg:hidden"
        />
      )}

      <aside
        className={`fixed top-0 bottom-0 left-0 z-50 flex w-72 flex-col border-r border-white/5 bg-slate-950 text-slate-100 transition-transform duration-300 ease-out lg:translate-x-0 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="pointer-events-none absolute inset-x-0 top-0 h-48 bg-gradient-to-b from-emerald-500/10 to-transparent" />

        {/* Brand */}
        <div className="relative flex h-16 shrink-0 items-center justify-between px-5">
          <Link href="/dashboard" onClick={onClose} className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-400 text-sm font-extrabold text-white shadow-lg shadow-emerald-500/25">
              IO
            </div>
            <div className="flex flex-col leading-tight">
              <span className="text-[15px] font-bold tracking-tight text-white">Inovasi Online</span>
              <span className="text-[11px] font-medium text-emerald-400">Admin Portal</span>
            </div>
          </Link>
          <button
            onClick={onClose}
            aria-label="Tutup menu"
            className="rounded-lg p-1.5 text-slate-400 transition-colors hover:bg-white/10 hover:text-white lg:hidden"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Navigation */}
        <div className="relative flex-1 overflow-y-auto px-3 pb-4 pt-2">
          {sections.map((section) => (
            <div key={section.title} className="mb-5">
              <div className="mb-1.5 px-3 text-[10.5px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                {section.title}
              </div>
              <nav className="space-y-0.5">
                {section.items.map((item) => {
                  const Icon = item.icon;

                  if (item.children) {
                    const childActive = item.children.some((c) => pathname.startsWith(c.href));
                    const open = openGroups[item.name] ?? childActive;

                    return (
                      <div key={item.href}>
                        <button
                          type="button"
                          onClick={() => setOpenGroups({ ...openGroups, [item.name]: !open })}
                          aria-expanded={open}
                          className={`group flex w-full items-center justify-between rounded-lg px-3 py-2 text-[13.5px] font-medium transition-colors ${
                            childActive
                              ? 'text-white'
                              : 'text-slate-400 hover:bg-white/5 hover:text-white'
                          }`}
                        >
                          <div className="flex items-center gap-3">
                            <Icon
                              className={`h-[18px] w-[18px] ${childActive ? 'text-emerald-400' : 'text-slate-500 group-hover:text-emerald-400'}`}
                            />
                            <span>{item.name}</span>
                          </div>
                          <ChevronDown
                            className={`h-4 w-4 text-slate-500 transition-transform duration-200 ${open ? 'rotate-180' : ''}`}
                          />
                        </button>
                        {open && (
                          <div className="animate-fade-in ml-[21px] mt-0.5 space-y-0.5 border-l border-white/10 pl-3">
                            {item.children.map((child) => {
                              const active = pathname.startsWith(child.href);
                              const ChildIcon = child.icon;
                              return (
                                <Link
                                  key={child.href}
                                  href={child.href}
                                  onClick={onClose}
                                  className={`flex items-center gap-2.5 rounded-lg px-3 py-1.5 text-[13px] transition-colors ${
                                    active
                                      ? 'bg-emerald-500/15 font-semibold text-emerald-300'
                                      : 'text-slate-400 hover:bg-white/5 hover:text-white'
                                  }`}
                                >
                                  <ChildIcon className="h-4 w-4" />
                                  {child.name}
                                </Link>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    );
                  }

                  const isActive =
                    item.href === '/dashboard' ? pathname === item.href : pathname.startsWith(item.href);

                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      onClick={onClose}
                      aria-current={isActive ? 'page' : undefined}
                      className={`group relative flex items-center justify-between rounded-lg px-3 py-2 text-[13.5px] font-medium transition-colors ${
                        isActive
                          ? 'bg-emerald-500/15 text-white'
                          : 'text-slate-400 hover:bg-white/5 hover:text-white'
                      }`}
                    >
                      {isActive && (
                        <span className="absolute -left-3 top-1/2 h-5 w-1 -translate-y-1/2 rounded-r-full bg-emerald-400" />
                      )}
                      <div className="flex items-center gap-3">
                        <Icon
                          className={`h-[18px] w-[18px] transition-colors ${
                            isActive ? 'text-emerald-400' : 'text-slate-500 group-hover:text-emerald-400'
                          }`}
                        />
                        <span>{item.name}</span>
                      </div>
                      {item.perm === 'orders' ? (
                        <OpenOrdersBadge />
                      ) : (
                        item.badge && (
                          <span className="rounded-md border border-emerald-500/25 bg-emerald-500/10 px-1.5 py-0.5 text-[10px] font-semibold text-emerald-300">
                            {item.badge}
                          </span>
                        )
                      )}
                    </Link>
                  );
                })}
              </nav>
            </div>
          ))}
        </div>
      </aside>
    </>
  );
}
