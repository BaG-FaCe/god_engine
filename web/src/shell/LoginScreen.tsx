import { Alert, Box, Button, Card, CardContent, Stack, TextField, Typography } from '@mui/material';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { useAuthStore } from '../stores';
import { authApi } from '../shared/api/http';
import { errorMessage } from '../shared/lib/errors';
import type { AuthUser } from '../shared/api/types/common';

/**
 * Full-screen login gate. Rendered whenever the application starts without a
 * valid session, so an unauthenticated user can never reach the platform shell.
 */
export function LoginScreen() {
  const setSession = useAuthStore((state) => state.setSession);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setPending(true);
    setError(null);
    try {
      const result = await authApi.login(email, password);
      setSession(result.user as AuthUser, result.token);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setPending(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        bgcolor: 'background.default',
        px: 2,
      }}
    >
      <Card sx={{ width: 400, maxWidth: '100%' }}>
        <CardContent>
          <Typography variant="h5" component="h1" sx={{ mb: 1 }}>
            God Engine
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
            Bitte melden Sie sich an, um die Plattform zu verwenden.
          </Typography>
          <form onSubmit={submit} noValidate>
            <Stack spacing={2}>
              {error && <Alert severity="error">{error}</Alert>}
              <TextField
                label="E-Mail"
                type="email"
                required
                autoFocus
                autoComplete="username"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />
              <TextField
                label="Passwort"
                type="password"
                required
                autoComplete="current-password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
              />
              <Button type="submit" variant="contained" size="large" disabled={pending}>
                Anmelden
              </Button>
            </Stack>
          </form>
        </CardContent>
      </Card>
    </Box>
  );
}
