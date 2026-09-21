import {
  Alert, Box, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle, IconButton,
  MenuItem, Paper, Stack, Switch, Table, TableBody, TableCell, TableContainer, TableHead,
  TableRow, TextField, Typography,
} from '@mui/material';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { EmptyState } from '../../../shared/components/EmptyState';
import { LoadingState } from '../../../shared/components/LoadingState';
import { QueryError } from '../../../shared/components/QueryError';
import {
  formatAmount, formatMoney, parseAmountToCents, formatPercent,
} from '../../../shared/lib/money';
import { errorMessage } from '../../../shared/lib/errors';
import type {
  FixedCost, FixedCostAllocation, FixedCostCategory, FixedCostUpsert,
  LaborCost, LaborCostUpsert, OverheadBase,
} from '../../../shared/api/types';
import {
  useLaborCosts, useFixedCosts, useOverheadRules,
  useLaborCostMutations, useFixedCostMutations, useOverheadRuleMutations,
  useProject, useProjectMutations,
} from '../api/queries';

const FIXED_CATEGORIES: Array<{ value: FixedCostCategory; label: string }> = [
  { value: 'labor', label: 'Arbeitskosten (fix)' },
  { value: 'development', label: 'Entwicklung' },
  { value: 'engineering', label: 'Konstruktion' },
  { value: 'quality_control', label: 'Qualitätskontrolle' },
  { value: 'packaging', label: 'Verpackung' },
  { value: 'sales', label: 'Vertrieb' },
  { value: 'depreciation', label: 'Abschreibung' },
  { value: 'other', label: 'Sonstiges' },
];

const ALLOCATIONS: Array<{ value: FixedCostAllocation; label: string }> = [
  { value: 'per_unit', label: 'Pro Einheit' },
  { value: 'per_month', label: 'Pro Monat (auf Einheiten verteilt)' },
  { value: 'per_batch', label: 'Pro Charge' },
];

const BASES: Array<{ value: OverheadBase; label: string }> = [
  { value: 'materials', label: 'Materialkosten' },
  { value: 'labor', label: 'Arbeitskosten' },
  { value: 'fixed_costs', label: 'Fixkosten' },
  { value: 'monthly_costs', label: 'Monatskosten' },
  { value: 'direct_cost', label: 'Direkte Kosten' },
  { value: 'subtotal', label: 'Zwischensumme' },
];

const labelFor = (list: Array<{ value: string; label: string }>, value: string) =>
  list.find((entry) => entry.value === value)?.label ?? value;

export function FixedCostsTab({ projectId }: { projectId: string }) {
  const labor = useLaborCosts(projectId);
  const fixed = useFixedCosts(projectId);
  const overhead = useOverheadRules(projectId);
  const project = useProject(projectId);

  const laborMutations = useLaborCostMutations(projectId);
  const fixedMutations = useFixedCostMutations(projectId);
  const overheadMutations = useOverheadRuleMutations(projectId);
  const projectMutations = useProjectMutations();

  const [laborOpen, setLaborOpen] = useState(false);
  const [editingLabor, setEditingLabor] = useState<LaborCost | null>(null);
  const [laborForm, setLaborForm] = useState<LaborCostUpsert>({
    employee: '', role: null, department: null, hours: 0, hourlyRateCents: 0, notes: null,
  });
  const [fixedOpen, setFixedOpen] = useState(false);
  const [editingFixed, setEditingFixed] = useState<FixedCost | null>(null);
  const [fixedForm, setFixedForm] = useState<FixedCostUpsert>({
    category: 'development', name: '', amountCents: 0, allocationBasis: 'per_unit', notes: null,
  });

  if (labor.isLoading || fixed.isLoading || overhead.isLoading || project.isLoading) {
    return <LoadingState label="Fix- und Gemeinkosten werden geladen …" />;
  }
  if (labor.isError) return <QueryError error={labor.error} />;
  if (fixed.isError) return <QueryError error={fixed.error} />;
  if (overhead.isError) return <QueryError error={overhead.error} />;

  const laborRows = labor.data?.data ?? [];
  const fixedRows = fixed.data?.data ?? [];
  const overheadRows = overhead.data?.data ?? [];
  const projectData = project.data;
  const autoRisk = projectData?.autoRiskSurcharge ?? false;
  const manualSurcharge = projectData?.riskSurchargePct ?? null;
  const suggestedRule = overheadRows.find((rule) => rule.autoFromRisk);

  const laborTotal = laborRows.reduce((sum, row) => sum + row.totalCents, 0);
  const fixedTotal = fixedRows.reduce((sum, row) => sum + row.amountCents, 0);

  const openLaborCreate = () => {
    setEditingLabor(null);
    setLaborForm({
      employee: '', role: null, department: null, hours: 0, hourlyRateCents: 0, notes: null,
    });
    setLaborOpen(true);
  };
  const openLaborEdit = (row: LaborCost) => {
    setEditingLabor(row);
    setLaborForm({
      employee: row.employee, role: row.role, department: row.department,
      hours: row.hours, hourlyRateCents: row.hourlyRateCents, notes: row.notes,
    });
    setLaborOpen(true);
  };
  const submitLabor = (event: FormEvent) => {
    event.preventDefault();
    if (editingLabor) {
      laborMutations.update.mutate(
        { id: editingLabor.id, item: laborForm },
        { onSuccess: () => setLaborOpen(false) },
      );
    } else {
      laborMutations.create.mutate(laborForm, { onSuccess: () => setLaborOpen(false) });
    }
  };

  const openFixedCreate = () => {
    setEditingFixed(null);
    setFixedForm({
      category: 'development', name: '', amountCents: 0, allocationBasis: 'per_unit', notes: null,
    });
    setFixedOpen(true);
  };
  const openFixedEdit = (row: FixedCost) => {
    setEditingFixed(row);
    setFixedForm({
      category: row.category, name: row.name, amountCents: row.amountCents,
      allocationBasis: row.allocationBasis, notes: row.notes,
    });
    setFixedOpen(true);
  };
  const submitFixed = (event: FormEvent) => {
    event.preventDefault();
    if (editingFixed) {
      fixedMutations.update.mutate(
        { id: editingFixed.id, item: fixedForm },
        { onSuccess: () => setFixedOpen(false) },
      );
    } else {
      fixedMutations.create.mutate(fixedForm, { onSuccess: () => setFixedOpen(false) });
    }
  };

  return (
    <Stack spacing={3}>
      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack direction="row" alignItems="center" spacing={2}>
          <Typography variant="subtitle1">Arbeitskosten</Typography>
          <Chip color="primary" label={`Summe: ${formatMoney(laborTotal)}`} />
          <Box sx={{ flexGrow: 1 }} />
          <Button onClick={openLaborCreate}>Mitarbeiter hinzufügen</Button>
        </Stack>
      </Paper>

      {laborRows.length === 0 ? (
        <EmptyState title="Keine Arbeitskosten" hint="Mitarbeiter, Stunden und Stundensatz erfassen." />
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Mitarbeiter</TableCell>
                <TableCell>Rolle</TableCell>
                <TableCell align="right">Stunden</TableCell>
                <TableCell align="right">Stundensatz</TableCell>
                <TableCell align="right">Summe</TableCell>
                <TableCell align="right">Aktionen</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {laborRows.map((row) => (
                <TableRow key={row.id}>
                  <TableCell>{row.employee}</TableCell>
                  <TableCell>{row.role ?? ''}</TableCell>
                  <TableCell align="right">{row.hours}</TableCell>
                  <TableCell align="right">{formatMoney(row.hourlyRateCents)}</TableCell>
                  <TableCell align="right">{formatMoney(row.totalCents)}</TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => openLaborEdit(row)} aria-label="Bearbeiten">✎</IconButton>
                    <IconButton size="small" color="error"
                      onClick={() => laborMutations.remove.mutate(row.id)} aria-label="Löschen">✕</IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack direction="row" alignItems="center" spacing={2}>
          <Typography variant="subtitle1">Fixkosten</Typography>
          <Chip color="primary" label={`Summe: ${formatMoney(fixedTotal)}`} />
          <Box sx={{ flexGrow: 1 }} />
          <Button onClick={openFixedCreate}>Fixkosten hinzufügen</Button>
        </Stack>
      </Paper>

      {fixedRows.length === 0 ? (
        <EmptyState title="Keine Fixkosten" hint="Entwicklung, Konstruktion, Qualitätskontrolle, Verpackung …" />
      ) : (
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Kategorie</TableCell>
                <TableCell>Name</TableCell>
                <TableCell align="right">Betrag</TableCell>
                <TableCell>Verrechnung</TableCell>
                <TableCell align="right">Aktionen</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {fixedRows.map((row) => (
                <TableRow key={row.id}>
                  <TableCell>{labelFor(FIXED_CATEGORIES, row.category)}</TableCell>
                  <TableCell>{row.name}</TableCell>
                  <TableCell align="right">{formatMoney(row.amountCents)}</TableCell>
                  <TableCell>{labelFor(ALLOCATIONS, row.allocationBasis)}</TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => openFixedEdit(row)} aria-label="Bearbeiten">✎</IconButton>
                    <IconButton size="small" color="error"
                      onClick={() => fixedMutations.remove.mutate(row.id)} aria-label="Löschen">✕</IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Typography variant="subtitle1" gutterBottom>Gemeinkosten-Zuschläge</Typography>
        <Stack direction="row" spacing={2} sx={{ mb: 1 }} flexWrap="wrap" useFlexGap>
          <Switch
            checked={autoRisk}
            onChange={(event) =>
              projectMutations.update.mutate({
                id: projectId,
                project: { autoRiskSurcharge: event.target.checked },
              })
            }
          />
          <Typography variant="body2" sx={{ alignSelf: 'center' }}>
            Risikoaufschlag automatisch aus Lieferrisiko-Score vorschlagen
          </Typography>
        </Stack>
        {suggestedRule?.suggestedPercentage != null && (
          <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
            Vorschlag für „{suggestedRule.name}“:{' '}
            {formatPercent(suggestedRule.suggestedPercentage)}
          </Typography>
        )}
        {!autoRisk && (
          <Stack direction="row" spacing={2} alignItems="center" sx={{ mb: 1 }}>
            <TextField
              label="Manueller Risikoaufschlag (%)" size="small" sx={{ width: 240 }}
              value={manualSurcharge === null ? '' : String((manualSurcharge * 100).toFixed(2))}
              onChange={(event) => {
                const raw = event.target.value.replace(',', '.');
                const value = Number.parseFloat(raw);
                projectMutations.update.mutate({
                  id: projectId,
                  project: { riskSurchargePct: Number.isNaN(value) ? null : value / 100 },
                });
              }}
            />
            <Typography variant="body2" color="text.secondary">
              leer = kein manueller Aufschlag
            </Typography>
          </Stack>
        )}
        <TableContainer component={Paper} variant="outlined">
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Name</TableCell>
                <TableCell>Basis</TableCell>
                <TableCell align="right">Prozent</TableCell>
                <TableCell>Auto (Risiko)</TableCell>
                <TableCell>Aktiv</TableCell>
                <TableCell align="right">Aktiv-Schalter</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {overheadRows.map((rule) => (
                <TableRow key={rule.id}>
                  <TableCell>{rule.name}</TableCell>
                  <TableCell>{labelFor(BASES, rule.base)}</TableCell>
                  <TableCell align="right">{formatPercent(rule.percentage)}</TableCell>
                  <TableCell>{rule.autoFromRisk ? 'Ja' : 'Nein'}</TableCell>
                  <TableCell>
                    <Switch
                      checked={rule.enabled}
                      onChange={(event) =>
                        overheadMutations.update.mutate({
                          id: rule.id,
                          item: { enabled: event.target.checked },
                        })
                      }
                      size="small"
                    />
                  </TableCell>
                  <TableCell align="right">
                    <IconButton
                      size="small" color="error" aria-label="Löschen"
                      onClick={() => overheadMutations.remove.mutate(rule.id)}
                    >
                      ✕
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      <Dialog open={laborOpen} onClose={() => setLaborOpen(false)}>
        <DialogTitle>{editingLabor ? 'Arbeitskosten bearbeiten' : 'Arbeitskosten'}</DialogTitle>
        <form onSubmit={submitLabor}>
          <DialogContent>
            <Stack spacing={2} sx={{ minWidth: 360 }}>
              <TextField label="Mitarbeiter" required value={laborForm.employee}
                onChange={(e) => setLaborForm({ ...laborForm, employee: e.target.value })} />
              <TextField label="Rolle" value={laborForm.role ?? ''}
                onChange={(e) => setLaborForm({ ...laborForm, role: e.target.value || null })} />
              <TextField label="Stunden" type="number" value={laborForm.hours}
                onChange={(e) => setLaborForm({ ...laborForm, hours: Number(e.target.value) || 0 })} />
              <TextField label="Stundensatz (€/h)" value={
                laborForm.hourlyRateCents === 0 ? '' : formatAmount(laborForm.hourlyRateCents)
              }
                onChange={(e) => setLaborForm({
                  ...laborForm,
                  hourlyRateCents: parseAmountToCents(e.target.value) ?? 0,
                })} />
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setLaborOpen(false)}>Abbrechen</Button>
            <Button type="submit" variant="contained">Speichern</Button>
          </DialogActions>
        </form>
      </Dialog>

      <Dialog open={fixedOpen} onClose={() => setFixedOpen(false)}>
        <DialogTitle>{editingFixed ? 'Fixkosten bearbeiten' : 'Fixkosten'}</DialogTitle>
        <form onSubmit={submitFixed}>
          <DialogContent>
            <Stack spacing={2} sx={{ minWidth: 360 }}>
              <TextField select label="Kategorie" value={fixedForm.category}
                onChange={(e) =>
                  setFixedForm({ ...fixedForm, category: e.target.value as FixedCostCategory })
                }>
                {FIXED_CATEGORIES.map((category) => (
                  <MenuItem key={category.value} value={category.value}>{category.label}</MenuItem>
                ))}
              </TextField>
              <TextField label="Name" required value={fixedForm.name}
                onChange={(e) => setFixedForm({ ...fixedForm, name: e.target.value })} />
              <TextField label="Betrag (€)" required value={formatAmount(fixedForm.amountCents)}
                onChange={(e) =>
                  setFixedForm({ ...fixedForm, amountCents: parseAmountToCents(e.target.value) ?? 0 })
                } />
              <TextField select label="Verrechnung" value={fixedForm.allocationBasis}
                onChange={(e) =>
                  setFixedForm({
                    ...fixedForm, allocationBasis: e.target.value as FixedCostAllocation,
                  })
                }>
                {ALLOCATIONS.map((allocation) => (
                  <MenuItem key={allocation.value} value={allocation.value}>
                    {allocation.label}
                  </MenuItem>
                ))}
              </TextField>
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setFixedOpen(false)}>Abbrechen</Button>
            <Button type="submit" variant="contained">Speichern</Button>
          </DialogActions>
        </form>
      </Dialog>

      {(projectMutations.update.isError || overheadMutations.remove.isError) && (
        <Alert severity="error">
          {errorMessage(projectMutations.update.error ?? overheadMutations.remove.error)}
        </Alert>
      )}
    </Stack>
  );
}
