import {
  Alert, Box, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle, IconButton,
  MenuItem, Paper, Stack, Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  TextField, Typography,
} from '@mui/material';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { EmptyState } from '../../../shared/components/EmptyState';
import { LoadingState } from '../../../shared/components/LoadingState';
import { QueryError } from '../../../shared/components/QueryError';
import {
  formatMoney, formatAmount, parseAmountToCents, formatPercent,
} from '../../../shared/lib/money';
import { formatPeriod } from '../../../shared/lib/format';
import { errorMessage } from '../../../shared/lib/errors';
import type {
  MonthlyCost, MonthlyCostCategory, MonthlyCostUpsert, SalesForecast, SalesForecastUpsert,
} from '../../../shared/api/types';
import {
  useMonthlyCosts, useForecasts, useGlobalCostTemplates,
  useMonthlyCostMutations, useForecastMutations, useApplyTemplate,
} from '../api/queries';

const CATEGORIES: Array<{ value: MonthlyCostCategory; label: string }> = [
  { value: 'rent', label: 'Miete' },
  { value: 'energy', label: 'Strom / Energie' },
  { value: 'marketing', label: 'Marketing' },
  { value: 'insurance', label: 'Versicherungen' },
  { value: 'hosting', label: 'Hosting' },
  { value: 'leasing', label: 'Leasing' },
  { value: 'maintenance', label: 'Wartung' },
  { value: 'software', label: 'Software' },
  { value: 'other', label: 'Sonstiges' },
];

const labelFor = (value: string) =>
  CATEGORIES.find((category) => category.value === value)?.label ?? value;

interface MonthlyForm {
  category: MonthlyCostCategory;
  name: string;
  amount: string;
  isRecurring: boolean;
  notes: string;
}

const EMPTY_MONTHLY: MonthlyForm = {
  category: 'rent', name: '', amount: '', isRecurring: true, notes: '',
};

function monthlyToForm(row: MonthlyCost): MonthlyForm {
  return {
    category: row.category, name: row.name,
    amount: formatAmount(row.amountCents), isRecurring: row.isRecurring, notes: row.notes ?? '',
  };
}

export function MonthlyCostsTab({ projectId }: { projectId: string }) {
  const monthly = useMonthlyCosts(projectId);
  const forecasts = useForecasts(projectId);
  const templates = useGlobalCostTemplates();
  const mutations = useMonthlyCostMutations(projectId);
  const forecastMutations = useForecastMutations(projectId);
  const applyTemplate = useApplyTemplate(projectId);

  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<MonthlyCost | null>(null);
  const [form, setForm] = useState<MonthlyForm>(EMPTY_MONTHLY);
  const [forecastOpen, setForecastOpen] = useState(false);
  const [editingForecast, setEditingForecast] = useState<SalesForecast | null>(null);
  const [forecastForm, setForecastForm] = useState<SalesForecastUpsert>({
    period: '', forecastUnits: 0, actualUnits: null, notes: null,
  });

  const set = (patch: Partial<MonthlyForm>) => setForm((prev) => ({ ...prev, ...patch }));

  const openCreate = () => {
    setEditing(null);
    setForm(EMPTY_MONTHLY);
    setOpen(true);
  };
  const openEdit = (row: MonthlyCost) => {
    setEditing(row);
    setForm(monthlyToForm(row));
    setOpen(true);
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    const payload: MonthlyCostUpsert = {
      category: form.category, name: form.name,
      amountCents: parseAmountToCents(form.amount) ?? 0,
      isRecurring: form.isRecurring, notes: form.notes || null,
    };
    if (editing) {
      mutations.update.mutate({ id: editing.id, item: payload }, { onSuccess: () => setOpen(false) });
    } else {
      mutations.create.mutate(payload, { onSuccess: () => setOpen(false) });
    }
  };

  const openForecastCreate = () => {
    setEditingForecast(null);
    setForecastForm({ period: '', forecastUnits: 0, actualUnits: null, notes: null });
    setForecastOpen(true);
  };
  const openForecastEdit = (row: SalesForecast) => {
    setEditingForecast(row);
    setForecastForm({
      period: row.period, forecastUnits: row.forecastUnits,
      actualUnits: row.actualUnits, notes: row.notes,
    });
    setForecastOpen(true);
  };
  const submitForecast = (event: FormEvent) => {
    event.preventDefault();
    if (editingForecast) {
      forecastMutations.update.mutate(
        { id: editingForecast.id, item: forecastForm },
        { onSuccess: () => setForecastOpen(false) },
      );
    } else {
      forecastMutations.create.mutate(forecastForm, { onSuccess: () => setForecastOpen(false) });
    }
  };

  if (monthly.isLoading || forecasts.isLoading) {
    return <LoadingState label="Monatskosten werden geladen …" />;
  }
  if (monthly.isError) return <QueryError error={monthly.error} />;

  const rows = monthly.data?.data ?? [];
  const total = rows.reduce((sum, row) => sum + row.amountCents, 0);
  const forecastRows = forecasts.data?.data ?? [];

  return (
    <Stack spacing={3}>
      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack direction="row" alignItems="center" spacing={2}>
          <Typography variant="subtitle1">Monatliche Kosten</Typography>
          <Chip color="primary" label={`Summe: ${formatMoney(total)}`} />
          <Box sx={{ flexGrow: 1 }} />
          <Button onClick={openCreate}>Position hinzufügen</Button>
        </Stack>
      </Paper>

      {rows.length === 0 ? (
        <EmptyState title="Keine monatlichen Kosten" hint="Erfasse Miete, Strom, Marketing …" />
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Kategorie</TableCell>
                <TableCell>Name</TableCell>
                <TableCell align="right">Betrag</TableCell>
                <TableCell>Wiederkehrend</TableCell>
                <TableCell>Notiz</TableCell>
                <TableCell align="right">Aktionen</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.map((row) => (
                <TableRow key={row.id}>
                  <TableCell>{labelFor(row.category)}</TableCell>
                  <TableCell>{row.name}</TableCell>
                  <TableCell align="right">{formatMoney(row.amountCents, row.currency)}</TableCell>
                  <TableCell>{row.isRecurring ? 'Ja' : 'Nein'}</TableCell>
                  <TableCell>{row.notes ?? ''}</TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => openEdit(row)} aria-label="Bearbeiten">✎</IconButton>
                    <IconButton size="small" color="error" onClick={() => mutations.remove.mutate(row.id)}
                      aria-label="Löschen">✕</IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {mutations.remove.isError && (
        <Alert severity="error">{errorMessage(mutations.remove.error)}</Alert>
      )}

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack direction="row" alignItems="center" spacing={2}>
          <Typography variant="subtitle1">Prognose vs. Realität</Typography>
          <Box sx={{ flexGrow: 1 }} />
          <Button onClick={openForecastCreate}>Monat hinzufügen</Button>
        </Stack>
      </Paper>

      {forecastRows.length === 0 ? (
        <EmptyState
          title="Keine Verkaufsprognose"
          hint="Erfasse prognostizierte und tatsächliche Verkäufe pro Monat."
        />
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Periode</TableCell>
                <TableCell align="right">Prognose</TableCell>
                <TableCell align="right">Tatsächlich</TableCell>
                <TableCell align="right">Abweichung</TableCell>
                <TableCell>Notiz</TableCell>
                <TableCell align="right">Aktionen</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {forecastRows.map((row) => {
                const deviation = row.actualUnits === null ? null : row.actualUnits - row.forecastUnits;
                return (
                  <TableRow key={row.id}>
                    <TableCell>{formatPeriod(row.period)}</TableCell>
                    <TableCell align="right">{row.forecastUnits}</TableCell>
                    <TableCell align="right">{row.actualUnits ?? '–'}</TableCell>
                    <TableCell align="right">
                      {deviation === null
                        ? '–'
                        : `${deviation > 0 ? '+' : ''}${deviation} (${formatPercent(
                            row.forecastUnits === 0 ? null : deviation / row.forecastUnits,
                          )})`}
                    </TableCell>
                    <TableCell>{row.notes ?? ''}</TableCell>
                    <TableCell align="right">
                      <IconButton size="small" onClick={() => openForecastEdit(row)} aria-label="Bearbeiten">✎</IconButton>
                      <IconButton size="small" color="error"
                        onClick={() => forecastMutations.remove.mutate(row.id)} aria-label="Löschen">✕</IconButton>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Typography variant="subtitle1" gutterBottom>Kosten-Vorlagen</Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          Globale Vorlagen (z. B. Online-Shop, Kleinserie) auf dieses Projekt anwenden.
        </Typography>
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
          {(templates.data?.data ?? []).length === 0 && (
            <Typography variant="body2" color="text.secondary">
              Noch keine Vorlagen vorhanden.
            </Typography>
          )}
          {(templates.data?.data ?? []).map((template) => (
            <Chip
              key={template.id}
              label={`${template.name} (${template.itemCount} Positionen)`}
              onClick={() => applyTemplate.mutate(template.id)}
              disabled={applyTemplate.isPending}
            />
          ))}
        </Stack>
        {applyTemplate.isError && (
          <Alert severity="error" sx={{ mt: 1 }}>{errorMessage(applyTemplate.error)}</Alert>
        )}
        {applyTemplate.isSuccess && (
          <Alert severity="success" sx={{ mt: 1 }}>Vorlage angewendet.</Alert>
        )}
      </Paper>

      <Dialog open={open} onClose={() => setOpen(false)}>
        <DialogTitle>{editing ? 'Kostenposition bearbeiten' : 'Kostenposition'}</DialogTitle>
        <form onSubmit={submit}>
          <DialogContent>
            <Stack spacing={2} sx={{ minWidth: 380 }}>
              <TextField select label="Kategorie" value={form.category}
                onChange={(e) => set({ category: e.target.value as MonthlyCostCategory })}>
                {CATEGORIES.map((category) => (
                  <MenuItem key={category.value} value={category.value}>{category.label}</MenuItem>
                ))}
              </TextField>
              <TextField label="Name" required value={form.name}
                onChange={(e) => set({ name: e.target.value })} />
              <TextField label="Betrag pro Monat (€)" required value={form.amount}
                onChange={(e) => set({ amount: e.target.value })} />
              <TextField
                label="Wiederkehrend" select value={form.isRecurring ? 'yes' : 'no'}
                onChange={(e) => set({ isRecurring: e.target.value === 'yes' })}
              >
                <MenuItem value="yes">Ja</MenuItem>
                <MenuItem value="no">Nein</MenuItem>
              </TextField>
              <TextField label="Notiz" value={form.notes}
                onChange={(e) => set({ notes: e.target.value })} />
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setOpen(false)}>Abbrechen</Button>
            <Button type="submit" variant="contained"
              disabled={mutations.create.isPending || mutations.update.isPending}>
              Speichern
            </Button>
          </DialogActions>
        </form>
      </Dialog>

      <Dialog open={forecastOpen} onClose={() => setForecastOpen(false)}>
        <DialogTitle>{editingForecast ? 'Prognose bearbeiten' : 'Prognose erfassen'}</DialogTitle>
        <form onSubmit={submitForecast}>
          <DialogContent>
            <Stack spacing={2} sx={{ minWidth: 320 }}>
              <TextField
                label="Periode (JJJJ-MM)" required placeholder="2026-09"
                value={forecastForm.period}
                onChange={(e) => setForecastForm({ ...forecastForm, period: e.target.value })}
              />
              <TextField
                label="Prognostizierte Verkäufe" type="number"
                value={forecastForm.forecastUnits}
                onChange={(e) =>
                  setForecastForm({ ...forecastForm, forecastUnits: Number(e.target.value) || 0 })
                }
              />
              <TextField
                label="Tatsächliche Verkäufe (leer = offen)" type="number"
                value={forecastForm.actualUnits ?? ''}
                onChange={(e) =>
                  setForecastForm({
                    ...forecastForm,
                    actualUnits: e.target.value === '' ? null : Number(e.target.value),
                  })
                }
              />
              <TextField
                label="Notiz" value={forecastForm.notes ?? ''}
                onChange={(e) => setForecastForm({ ...forecastForm, notes: e.target.value || null })}
              />
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setForecastOpen(false)}>Abbrechen</Button>
            <Button type="submit" variant="contained">Speichern</Button>
          </DialogActions>
        </form>
      </Dialog>
    </Stack>
  );
}

