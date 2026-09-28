import { Alert, Box, Button, Card, CardActionArea, CardContent, Chip, Stack, Typography } from '@mui/material';
import { Suspense, useEffect, useMemo, useState } from 'react';
import { Link as RouterLink, Route, Routes, useLocation } from 'react-router-dom';
import { ErrorBoundary } from './shared/components/ErrorBoundary';
import { LoadingState } from './shared/components/LoadingState';
import { systemSetupApi } from './shared/api/systemSetup';
import { MODULES, findModule, type ModuleDescriptor } from './shared/module-registry';
import { AppShell } from './shell/AppShell';
import { SetupScreen } from './shell/SetupScreen';

const MODULE_LABELS: Record<string, string> = {
  calculate: '∑',
  inventory_2: '▦',
  precision_manufacturing: '⚙',
  warehouse: '▤',
  insights: '📈',
  crisis_alert: '⚠',
};

function ModuleTile({ module }: { module: ModuleDescriptor }) {
  const disabled = module.status === 'coming_soon';
  return (
    <Card sx={{ height: '100%' }}>
      <CardActionArea
        component={disabled ? 'div' : RouterLink}
        {...(disabled ? {} : { to: `/modules/${module.id}` })}
        sx={{ height: '100%', cursor: disabled ? 'not-allowed' : 'pointer' }}
        aria-label={module.title}
      >
        <CardContent>
          <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
            <Box
              sx={{
                width: 36,
                height: 36,
                borderRadius: 1,
                bgcolor: disabled ? 'action.disabledBackground' : 'primary.main',
                color: disabled ? 'text.disabled' : 'primary.contrastText',
                display: 'grid',
                placeItems: 'center',
                fontSize: 18,
              }}
              aria-hidden
            >
              {MODULE_LABELS[module.icon] ?? '•'}
            </Box>
            <Typography variant="subtitle1" fontWeight={600}>
              {module.title}
            </Typography>
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ minHeight: 60 }}>
            {module.description}
          </Typography>
          <Chip
            size="small"
            label={disabled ? 'Coming Soon' : 'Verfügbar'}
            color={disabled ? 'default' : 'success'}
            sx={{ mt: 2 }}
          />
        </CardContent>
      </CardActionArea>
    </Card>
  );
}

function HomePage() {
  return (
    <Stack spacing={3}>
      <Box>
        <Typography variant="h5">Verkaufspreis-Kalkulationsplattform</Typography>
        <Typography variant="body1" color="text.secondary">
          Modulare Plattform: Jede Kachel ist ein eigenständig ladendes Modul. Nicht geöffnete
          Module werden nicht geladen — weder Code noch Daten.
        </Typography>
      </Box>
      <Box
        sx={{
          display: 'grid',
          gap: 2,
          gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr', lg: 'repeat(3, 1fr)' },
        }}
      >
        {MODULES.map((module) => (
          <ModuleTile key={module.id} module={module} />
        ))}
      </Box>
    </Stack>
  );
}

function ModuleHost() {
  const location = useLocation();
  const module = useMemo(() => {
    const segment = location.pathname.split('/')[2];
    return findModule(segment);
  }, [location.pathname]);

  if (!module) {
    return <Alert severity="warning">Unbekanntes Modul.</Alert>;
  }

  const Component = module.component;
  return (
    <ErrorBoundary>
      <Suspense fallback={<LoadingState label={`Modul ${module.title} wird geladen …`} />}>
        <Component />
      </Suspense>
    </ErrorBoundary>
  );
}

/**
 * Shell routing.
 *
 * Only the routes that exist are registered; module code arrives through the
 * lazy imports in `module-registry.ts`.
 *
 * First-run gate: the application persists its data in four SQL databases, so
 * as long as no SQL backend is configured the setup mask is shown instead of
 * the application shell (the API refuses persistent requests with 503 until
 * setup succeeds).
 */
export default function App() {
  const [setup, setSetup] = useState<{ loading: boolean; required: boolean }>({
    loading: true,
    required: false,
  });

  useEffect(() => {
    let cancelled = false;
    systemSetupApi
      .status()
      .then((status) => {
        if (!cancelled) setSetup({ loading: false, required: status.setupRequired });
      })
      .catch(() => {
        // If the status cannot be read the shell is shown; the API surfaces the
        // setup requirement per request instead.
        if (!cancelled) setSetup({ loading: false, required: false });
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (setup.loading) {
    return <LoadingState label="Anwendung wird gestartet …" />;
  }

  if (setup.required) {
    return <SetupScreen onCompleted={() => window.location.reload()} />;
  }

  return (
    <Routes>
      <Route path="/setup" element={<SetupScreen />} />
      <Route element={<AppShell />}>
        <Route path="/" element={<HomePage />} />
        <Route path="/modules/:moduleId/*" element={<ModuleHost />} />
        <Route
          path="*"
          element={
            <Stack spacing={2}>
              <Alert severity="info">Seite nicht gefunden.</Alert>
              <Button component={RouterLink} to="/" variant="contained">
                Zur Startseite
              </Button>
            </Stack>
          }
        />
      </Route>
    </Routes>
  );
}
