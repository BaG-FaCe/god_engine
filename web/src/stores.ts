import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { AuthUser } from './shared/api/types/common';
import { authApi, getToken, setToken as persistToken } from './shared/api/http';

type AuthStatus = 'loading' | 'authenticated' | 'unauthenticated';

interface AuthState {
  user: AuthUser | null;
  /** Startup gate state. Starts as `loading` and is never persisted, so every
   *  reload re-validates the token against the backend (fail closed). */
  status: AuthStatus;
  setSession: (user: AuthUser, token: string) => void;
  clearSession: () => void;
  /** Validates a remembered token against `/auth/me`. Invalid, expired, revoked
   *  or unreadable tokens clear the local session and yield `unauthenticated`. */
  bootstrap: () => Promise<void>;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      status: 'loading',
      setSession: (user, token) => {
        persistToken(token);
        set({ user, status: 'authenticated' });
      },
      clearSession: () => {
        persistToken(null);
        set({ user: null, status: 'unauthenticated' });
      },
      bootstrap: async () => {
        const token = getToken();
        if (!token) {
          set({ user: null, status: 'unauthenticated' });
          return;
        }
        try {
          const { user } = await authApi.me();
          set({ user: user as AuthUser, status: 'authenticated' });
        } catch {
          // Fail closed: any validation failure means "not authenticated".
          persistToken(null);
          set({ user: null, status: 'unauthenticated' });
        }
      },
    }),
    {
      name: 'god-engine.auth',
      // Only the identity is persisted; `status` always restarts as `loading`.
      partialize: (state) => ({ user: state.user }),
    },
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

