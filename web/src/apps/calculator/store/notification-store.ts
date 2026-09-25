import { create } from 'zustand';

/**
 * Local, non-persisted notification UI state (Update-Prompt Aufgabe 2).
 *
 * The *server* truth (list + unread count) lives in TanStack Query (polling);
 * this store only holds the bits that are pure UI: whether the dropdown is open
 * and the timestamp the user last looked at the list.
 */
interface NotificationUiState {
  panelOpen: boolean;
  lastSeenAt: string | null;
  openPanel: () => void;
  closePanel: () => void;
  togglePanel: () => void;
  markSeen: () => void;
}

export const useNotificationUiStore = create<NotificationUiState>()((set) => ({
  panelOpen: false,
  lastSeenAt: null,
  openPanel: () => set({ panelOpen: true }),
  closePanel: () => set({ panelOpen: false }),
  togglePanel: () => set((state) => ({ panelOpen: !state.panelOpen })),
  markSeen: () => set({ lastSeenAt: new Date().toISOString() }),
}));
