'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { AdminUser } from '../types';
import { adminApi, clearSession } from '../lib/api';

interface AuthContextType {
  user: AdminUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<AdminUser>;
  logout: () => Promise<void>;
  isSuperAdmin: boolean;
  hasPermission: (permissionKey: string) => boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Optimistic render from cached profile, then verify against the cookie session.
    try {
      const savedUser = localStorage.getItem('admin_user');
      if (savedUser) setUser(JSON.parse(savedUser));
    } catch {
      // invalid json
    }

    adminApi.getMe()
      .then((adminUser) => {
        setUser(adminUser);
        localStorage.setItem('admin_user', JSON.stringify(adminUser));
      })
      .catch(() => {
        clearSession();
        setUser(null);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const login = async (email: string, password: string): Promise<AdminUser> => {
    const res = await adminApi.login({ email, password });
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
      clearSession();
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
        isAuthenticated: !!user,
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
