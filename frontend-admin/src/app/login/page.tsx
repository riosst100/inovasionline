'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../../context/AuthContext';
import { ShieldCheck, Lock, Mail, Eye, EyeOff, Loader2, KeyRound, Sparkles } from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const { login, token, isLoading } = useAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (!isLoading && token) {
      router.replace('/dashboard');
    }
  }, [token, isLoading, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);

    try {
      await login(email, password);
      router.push('/dashboard');
    } catch (err: any) {
      setError(err?.message || 'Login gagal. Periksa kembali email dan kata sandi Anda.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleFillSuperAdmin = () => {
    setEmail('admin@inovasionline.com');
    setPassword('password');
    setError(null);
  };

  return (
    <div className="relative flex min-h-screen items-center justify-center bg-slate-950 px-4 py-12 text-slate-100 overflow-hidden">
      {/* Decorative background glow circles */}
      <div className="absolute top-1/4 -left-20 h-96 w-96 rounded-full bg-emerald-600/15 blur-3xl" />
      <div className="absolute bottom-1/4 -right-20 h-96 w-96 rounded-full bg-teal-600/15 blur-3xl" />

      <div className="relative w-full max-w-md">
        {/* Card Container */}
        <div className="rounded-3xl border border-slate-800 bg-slate-900/90 p-8 shadow-2xl backdrop-blur-xl">
          {/* Logo & Header */}
          <div className="flex flex-col items-center text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-400 font-extrabold text-2xl text-white shadow-lg shadow-emerald-500/25">
              IO
            </div>
            <h2 className="mt-4 text-2xl font-bold tracking-tight text-white">
              Admin Portal
            </h2>
            <p className="mt-1 text-xs text-slate-400">
              Masuk untuk mengelola Inovasi Online & manajemen hak akses multi-role
            </p>
          </div>

          {/* Quick Demo Super Admin Button */}
          <div className="mt-6 rounded-2xl bg-slate-800/80 p-3.5 border border-slate-700/60">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-xs font-semibold text-emerald-400">
                <Sparkles className="h-3.5 w-3.5" />
                <span>Akun Default Super Admin:</span>
              </div>
              <button
                type="button"
                onClick={handleFillSuperAdmin}
                className="rounded-lg bg-emerald-500/20 px-2.5 py-1 text-[11px] font-semibold text-emerald-300 hover:bg-emerald-500/30 transition-colors border border-emerald-500/30"
              >
                Gunakan Kredensial
              </button>
            </div>
            <p className="mt-1 text-[11px] text-slate-400">
              <span className="text-slate-300 font-mono">admin@inovasionline.com</span> | pass: <span className="text-slate-300 font-mono">password</span>
            </p>
          </div>

          {/* Error Message */}
          {error && (
            <div className="mt-4 rounded-xl border border-rose-500/30 bg-rose-500/10 p-3.5 text-xs text-rose-300">
              {error}
            </div>
          )}

          {/* Form */}
          <form onSubmit={handleSubmit} className="mt-6 space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Alamat Email
              </label>
              <div className="relative">
                <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3.5 text-slate-500">
                  <Mail className="h-4 w-4" />
                </div>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@inovasionline.com"
                  required
                  className="w-full rounded-xl border border-slate-700 bg-slate-800/80 py-2.5 pl-10 pr-3.5 text-sm text-white placeholder-slate-500 outline-none transition-all focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Kata Sandi
              </label>
              <div className="relative">
                <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3.5 text-slate-500">
                  <Lock className="h-4 w-4" />
                </div>
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="w-full rounded-xl border border-slate-700 bg-slate-800/80 py-2.5 pl-10 pr-10 text-sm text-white placeholder-slate-500 outline-none transition-all focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 flex items-center pr-3.5 text-slate-500 hover:text-slate-300"
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={isSubmitting}
              className="mt-2 flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-500 py-2.5 px-4 text-sm font-bold text-white shadow-lg shadow-emerald-600/30 transition-all hover:from-emerald-500 hover:to-teal-400 disabled:opacity-50"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>Memverifikasi...</span>
                </>
              ) : (
                <>
                  <KeyRound className="h-4 w-4" />
                  <span>Masuk ke Dashboard</span>
                </>
              )}
            </button>
          </form>

          {/* Footer Security Note */}
          <div className="mt-6 flex items-center justify-center gap-1.5 text-center text-[11px] text-slate-500">
            <ShieldCheck className="h-3.5 w-3.5 text-emerald-400" />
            <span>Koneksi aman terenkripsi API Inovasi Online</span>
          </div>
        </div>
      </div>
    </div>
  );
}
