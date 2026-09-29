import {
  AppBar, Box, Button, Container, Divider, Drawer, IconButton, List, ListItemButton,
  ListItemText, Stack, Toolbar, Typography,
} from '@mui/material';
import { useState } from 'react';
import { Link as RouterLink, Outlet, useLocation } from 'react-router-dom';
import { MODULES } from '../shared/module-registry';
import { useAuthStore } from '../stores';
import { authApi } from '../shared/api/http';

const DRAWER_WIDTH = 264;

/**
 * Application shell: header, module navigation, content outlet.
 *
 * The shell knows the module registry but never imports module code, so opening
 * the app costs the shell bundle only. It is only mounted once the startup
 * authentication gate has succeeded (see `App.tsx`), so a user always exists.
 */
export function AppShell() {
  const [open, setOpen] = useState(false);
  const location = useLocation();
  const user = useAuthStore((state) => state.user);
  const clearSession = useAuthStore((state) => state.clearSession);

  const handleLogout = async () => {
    try {
      await authApi.logout();
    } catch {
      // Best effort: the local session is cleared regardless, so the gate
      // re-runs on the next navigation/startup.
    }
    clearSession();
  };

  const nav = (
    <Box sx={{ width: DRAWER_WIDTH }} role="navigation" aria-label="Module">
      <Toolbar>
        <Typography variant="subtitle1">Module</Typography>
      </Toolbar>
      <Divider />
      <List>
        {MODULES.map((module) => {
          const disabled = module.status === 'coming_soon';
          const selected = location.pathname.startsWith(`/modules/${module.id}`);
          return (
            <ListItemButton
              key={module.id}
              component={disabled ? 'div' : RouterLink}
              {...(disabled ? {} : { to: `/modules/${module.id}` })}
              selected={selected}
              disabled={disabled}
              onClick={() => setOpen(false)}
            >
              <ListItemText
                primary={module.title}
                secondary={disabled ? 'Coming Soon' : undefined}
              />
            </ListItemButton>
          );
        })}
      </List>
    </Box>
  );

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      <AppBar position="fixed" sx={{ zIndex: (theme) => theme.zIndex.drawer + 1 }}>
        <Toolbar>
          <IconButton
            color="inherit"
            edge="start"
            onClick={() => setOpen((value) => !value)}
            sx={{ mr: 1 }}
            aria-label="Navigation umschalten"
          >
            ☰
          </IconButton>
          <Typography variant="h6" sx={{ flexGrow: 1 }}>
            God Engine · Verkaufspreis-Kalkulation
          </Typography>
          {user && (
            <Stack direction="row" spacing={1} alignItems="center">
              <Typography variant="body2" sx={{ color: 'inherit', opacity: 0.9 }}>
                {user.name || user.email}
              </Typography>
              <Button color="inherit" size="small" onClick={() => void handleLogout()}>
                Abmelden
              </Button>
            </Stack>
          )}
          <Button color="inherit" component={RouterLink} to="/">
            Startseite
          </Button>
        </Toolbar>
      </AppBar>

      <Drawer
        variant="permanent"
        sx={{
          display: { xs: 'none', md: 'block' },
          width: DRAWER_WIDTH,
          flexShrink: 0,
          [`& .MuiDrawer-paper`]: { width: DRAWER_WIDTH, boxSizing: 'border-box' },
        }}
        open
      >
        <Toolbar />
        {nav}
      </Drawer>

      <Drawer open={open} onClose={() => setOpen(false)} sx={{ display: { md: 'none' } }}>
        {nav}
      </Drawer>

      <Box component="main" sx={{ flexGrow: 1, bgcolor: 'background.default', minWidth: 0 }}>
        <Toolbar />
        <Container maxWidth="xl" sx={{ py: 3 }}>
          <Stack spacing={3}>
            <Outlet />
          </Stack>
        </Container>
      </Box>
    </Box>
  );
}