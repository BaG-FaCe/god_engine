import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Container,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { systemSetupApi, type SetupStatus, type SetupTestResult } from '../shared/api/systemSetup';
import { errorMessage } from '../shared/lib/errors';

interface FormState {
  adapter: string;
  server: string;
  port: string;
  username: string;
  password: string;
}

const EMPTY_FORM: FormState = { adapter: 'sqlserver', server: '', port: '', username: '', password: '' };
const DEFAULT_PORTS: Record<string, string> = { sqlserver: '1433', mariadb: '3306' };

/**
 * First-run SQL backend setup (the "setup mask").
 *
 * The application cannot serve persistent data before the four logical
 * databases exist, so this screen is shown whenever no SQL backend has been
 * configured yet (see `App.tsx`). "Verbindung testen" verifies connectivity
 * without changing anything; "Speichern & Einrichten" provisions the four
 * databases (productdata / users / events / logs), applies the schema, migrates
 * the legacy data, seeds the initial entry and verifies the result.
 */
export function SetupScreen({ onCompleted }: { onCompleted?: () => void } = {}) {
  const [status, setStatus] = useState<SetupStatus | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [testResult, setTestResult] = useState<SetupTestResult | null>(null);
  const [summary, setSummary] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState<'test' | 'complete' | null>(null);
  const [done, setDone] = useState(false);

  useEffect(() => {
    let cancelled = false;
    systemSetupApi
      .status()
      .then((result) => {
        if (!cancelled) setStatus(result);
      })
      .catch(() => {
        /* status is informational; ignore failures */
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const set = (key: keyof FormState) => (event: { target: { value: string } }) => {
    setForm((prev) => ({ ...prev, [key]: event.target.value }));
    // Any change invalidates a previous successful connection test.
    if (key !== 'adapter') setTestResult(null);
  };

  const setAdapter = (adapter: string) => setForm((prev) => ({ ...prev, adapter, port: '' }));

  const input = () => ({
    adapter: form.adapter,
    server: form.server.trim(),
    port: form.port.trim() || DEFAULT_PORTS[form.adapter],
    username: form.username.trim(),
    password: form.password,
  });

  const runTest = async (event: FormEvent) => {
    event.preventDefault();
    setPending('test');
    setError(null);
    setTestResult(null);
    try {
      setTestResult(await systemSetupApi.test(input()));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setPending(null);
    }
  };

  const runComplete = async () => {
    setPending('complete');
    setError(null);
    setSummary(null);
    try {
      const result = await systemSetupApi.complete(input());
      const created = result.provisioned.created.join(', ') || '—';
      const verified = result.verification?.ok === false ? 'Verifikation FEHLGESCHLAGEN' : 'Verifikation ok';
      setSummary(
        `Einrichtung abgeschlossen: ${result.schema.migrated} Migrationen, ` +
          `Datenbanken angelegt [${created}], ${verified}, ` +
          `initialer Eintrag angelegt (${result.seeded.users} Benutzer, ` +
          `${result.seeded.projects} Projekt). Die Anwendung nutzt jetzt ${result.adapter}.`,
      );
      setDone(true);
      onCompleted?.();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setPending(null);
    }
  };

  return (
    <Container maxWidth="sm" sx={{ py: 6 }}>
      <Card>
        <CardContent>
          <Stack spacing={3}>
            <Box>
              <Typography variant="h5">SQL-Backend einrichten</Typography>
              <Typography variant="body2" color="text.secondary">
                Die Anwendung speichert ihre Daten in vier logischen Datenbanken. Fehlende
                Datenbanken werden automatisch angelegt und das Schema wird angewendet.
              </Typography>
              <Stack direction="row" spacing={1} sx={{ mt: 1 }} flexWrap="wrap" useFlexGap>
                {['productdata', 'users', 'events', 'logs'].map((name) => (
                  <Chip key={name} size="small" variant="outlined" label={name} />
                ))}
              </Stack>
              {status && (
                <Stack direction="row" spacing={1} sx={{ mt: 1 }}>
                  <Chip
                    size="small"
                    label={`Backend: ${status.adapter}`}
                    color={status.adapter === 'sqlite' ? 'default' : 'success'}
                  />
                  {status.sqlServerConfigured && (
                    <Chip size="small" label="bereits konfiguriert" color="info" />
                  )}
                </Stack>
              )}
            </Box>

            {error && <Alert severity="error">{error}</Alert>}
            {summary && <Alert severity="success">{summary}</Alert>}

            <form onSubmit={runTest}>
              <Stack spacing={2}>
                <FormControl fullWidth>
                  <InputLabel id="sql-adapter-label">Datenbank-Typ</InputLabel>
                  <Select
                    labelId="sql-adapter-label"
                    label="Datenbank-Typ"
                    value={form.adapter}
                    onChange={(event) => setAdapter(event.target.value)}
                  >
                    <MenuItem value="sqlserver">Microsoft SQL Server</MenuItem>
                    <MenuItem value="mariadb">MariaDB / MySQL</MenuItem>
                  </Select>
                </FormControl>
                <TextField
                  label="Server / IP"
                  required
                  value={form.server}
                  onChange={set('server')}
                  helperText="z. B. sql.example.com oder eine IP-Adresse"
                />
                <TextField
                  label="Port"
                  value={form.port}
                  onChange={set('port')}
                  placeholder={DEFAULT_PORTS[form.adapter]}
                />
                <TextField
                  label="Benutzername"
                  required
                  value={form.username}
                  onChange={set('username')}
                />
                <TextField
                  label="Passwort"
                  type="password"
                  required
                  value={form.password}
                  onChange={set('password')}
                  autoComplete="new-password"
                />

                {testResult && testResult.ok && (
                  <Alert severity="info">
                    Verbindung erfolgreich ({testResult.serverVersion}).
                    {testResult.databases && (
                      <>
                        {' '}
                        Vorhanden: {testResult.databases.existing.join(', ') || 'keine'}; fehlt:{' '}
                        {testResult.databases.missing.join(', ') || 'keine'}.
                      </>
                    )}
                  </Alert>
                )}

                <Stack direction="row" spacing={2}>
                  <Button type="submit" variant="outlined" disabled={pending !== null}>
                    {pending === 'test' ? 'Prüfe …' : 'Verbindung testen'}
                  </Button>
                  <Button
                    variant="contained"
                    disabled={pending !== null || done || !testResult?.ok}
                    onClick={runComplete}
                  >
                    {pending === 'complete' ? 'Richte ein …' : 'Speichern & Einrichten'}
                  </Button>
                </Stack>
              </Stack>
            </form>
          </Stack>
        </CardContent>
      </Card>
    </Container>
  );
}

