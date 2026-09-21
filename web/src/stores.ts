import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { AuthUser } from './shared/api/types/common';
import { getToken, setToken as persistToken } from './shared/api/http';

interface AuthState {
  user: AuthUser | null;
  token: string | null;
  setSession: (user: AuthUser, token: string) => void;
  clearSession: () => void;
  hydrate: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      setSession: (user, token) => {
        persistToken(token);
        set({ user, token });
      },
      clearSession: () => {
        persistToken(null);
        set({ user: null, token: null });
      },
      hydrate: () => {
        const token = getToken();
        if (!token) set({ user: null, token: null });
      },
    }),
    { name: 'god-engine.auth', partialize: (state) => ({ user: state.user }) },
  ),
);

interface ProjectSelectionState {
  projectId: string | null;
  selectProject: (id: string | null) => void;
}

export const useProjectStore = create<ProjectSelectionState>()(
  persist(
    (set) => ({ projectId: null, selectProject: (projectId) => set({ projectId }) }),
    { name: 'god-engine.project' },
  ),
);
