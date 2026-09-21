import {
  AppBar, Box, Button, Container, Divider, Drawer, IconButton, List, ListItemButton,
  ListItemText, Stack, TextField, Toolbar, Typography, Dialog, DialogActions,
  DialogContent, DialogTitle, Alert,
} from '@mui/material';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link as RouterLink, Outlet, useLocation } from 'react-router-dom';
import { MODULES } from '../shared/module-registry';
import { useAuthStore } from '../stores';
import { authApi } from '../shared/api/http';
import { errorMessage } from '../shared/lib/errors';

const DRAWER_WIDTH = 264;
const SEED_HINT = 'admin@god-engine.local / GodEngine-Admin-123';

function LoginDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const setSession = useAuthStore((state) => state.setSession);
  const [email, setEmail] = useState('admin@god-engine.local');
  const [password, setPassword] = useState('GodEngine-Admin-123');
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setPending(true);
    setError(null);
    try {
      const result = await authApi.login(email, password);
      setSession(result.user as never, result.token);
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setPending(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose}>
      <DialogTitle>Anmelden</DialogTitle>
      <form onSubmit={submit}>
        <DialogContent>
          <Stack spacing={2} sx={{ minWidth: 320 }}>
            {error && <Alert severity="error">{error}</Alert>}
            <TextField
              label="E-Mail" type="email" required value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
            <TextField
              label="Passwort" type="password" required value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
            <Typography variant="caption" color="text.secondary">
              Seed-Zugang: {SEED_HINT}
            </Typography>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={onClose}>Abbrechen</Button>
          <Button type="submit" variant="contained" disabled={pending}>
            Anmelden
          </Button>
        </DialogActions>
      </form>
    </Dialog>
  );
}

/**
 * Application shell: header, module navigation, content outlet.
 *
 * The shell knows the module registry but never imports module code, so opening
 * the app costs the shell bundle only.
 */
export function AppShell() {
  const [open, setOpen] = useState(false);
  const [loginOpen, setLoginOpen] = useState(false);
  const location = useLocation();
  const user = useAuthStore((state) => state.user);
  const clearSession = useAuthStore((state) => state.clearSession);

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
          {user ? (
            <Stack direction="row" spacing={1} alignItems="center">
              <Typography variant="body2" sx={{ color: 'inherit', opacity: 0.9 }}>
                {user.name || user.email}
              </Typography>
              <Button color="inherit" size="small" onClick={() => clearSession()}>
                Abmelden
              </Button>
            </Stack>
          ) : (
            <Button color="inherit" size="small" onClick={() => setLoginOpen(true)}>
              Anmelden
            </Button>
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
    <LoginDialog open={loginOpen} onClose={() => setLoginOpen(false)} />

    </Box>
  );
}