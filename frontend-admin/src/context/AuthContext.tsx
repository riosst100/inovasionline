'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { AdminUser } from '../types';
import { adminApi, setToken, removeToken } from '../lib/api';

interface AuthContextType {
  user: AdminUser | null;
  token: string | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<AdminUser>;
  logout: () => Promise<void>;
  isSuperAdmin: boolean;
  hasPermission: (permissionKey: string) => boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [token, setTokenState] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const savedToken = typeof window !== 'undefined' ? localStorage.getItem('admin_token') : null;
    const savedUser = typeof window !== 'undefined' ? localStorage.getItem('admin_user') : null;

    if (savedToken) {
      setTokenState(savedToken);
      if (savedUser) {
        try {
          setUser(JSON.parse(savedUser));
        } catch {
          // invalid json
        }
      }
      // Re-verify admin profile
      adminApi.getMe()
        .then((adminUser) => {
          setUser(adminUser);
          localStorage.setItem('admin_user', JSON.stringify(adminUser));
        })
        .catch(() => {
          removeToken();
          setUser(null);
          setTokenState(null);
        })
        .finally(() => {
          setIsLoading(false);
        });
    } else {
      setIsLoading(false);
    }
  }, []);

  const login = async (email: string, password: string): Promise<AdminUser> => {
    const res = await adminApi.login({ email, password });
    setToken(res.token);
    setTokenState(res.token);
    setUser(res.user);
    localStorage.setItem('admin_user', JSON.stringify(res.user));
    return res.user;
  };

  const logout = async (): Promise<void> => {
    try {
      await adminApi.logout();
    } catch {
      // ignore
    } finally {
      setUser(null);
      setTokenState(null);
      removeToken();
      window.location.href = '/login';
    }
  };

  const isSuperAdmin = user?.is_super_admin || user?.role?.slug === 'super_admin';

  const hasPermission = (permissionKey: string): boolean => {
    if (isSuperAdmin) return true;
    const perms = user?.role?.permissions || [];
    return perms.includes('*') || perms.includes(permissionKey);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isLoading,
        login,
        logout,
        isSuperAdmin: !!isSuperAdmin,
        hasPermission,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
