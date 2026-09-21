import {
  Alert, Box, Button, Card, CardActions, CardContent, Chip, Dialog, DialogActions,
  DialogContent, DialogTitle, FormControl, FormControlLabel, Checkbox, Grid, IconButton,
  InputLabel, MenuItem, Paper, Select, Stack, TextField, Tooltip, Typography,
} from '@mui/material';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { EmptyState } from '../../../shared/components/EmptyState';
import { LoadingState } from '../../../shared/components/LoadingState';
import { QueryError } from '../../../shared/components/QueryError';
import { RiskAmpel, levelForScore } from '../../../shared/components/RiskAmpel';
import { formatLeadTime, formatNumber } from '../../../shared/lib/format';
import { formatMoney } from '../../../shared/lib/money';
import { errorMessage } from '../../../shared/lib/errors';
import type {
  LeadTimeUnit, Material, MaterialType, TransportMode,
} from '../../../shared/api/types';
import {
  useLeadTimeAnalysis, useMaterials, useSuppliers,
  useMaterialMutations,
} from '../api/queries';
import { riskApi } from '../api/risk';
import { useMutation } from '@tanstack/react-query';

const TYPES: Array<{ value: MaterialType; label: string }> = [
  { value: 'raw_material', label: 'Rohmaterial' },
  { value: 'component', label: 'Bauteil' },
  { value: 'fastener', label: 'Verbindungselement' },
  { value: 'electronics', label: 'Elektronik' },
  { value: 'packaging', label: 'Verpackung' },
  { value: 'consumable', label: 'Verbrauchsmaterial' },
  { value: 'service', label: 'Dienstleistung' },
  { value: 'other', label: 'Sonstiges' },
];

const UNITS: Array<{ value: LeadTimeUnit; label: string }> = [
  { value: 'days', label: 'Tage' },
  { value: 'weeks', label: 'Wochen' },
  { value: 'months', label: 'Monate' },
];

const TRANSPORT: Array<{ value: TransportMode; label: string }> = [
  { value: 'sea', label: 'Seefracht' },
  { value: 'air', label: 'Luftfracht' },
  { value: 'road', label: 'Straße' },
  { value: 'rail', label: 'Schiene' },
  { value: 'multimodal', label: 'Multimodal' },
];

interface FormState {
  name: string;
  materialType: MaterialType;
  supplierId: string;
  articleNumber: string;
  description: string;
  unit: string;
  unitPrice: string;
  priceIncludesTax: boolean;
  quantity: string;
  minOrderQuantity: string;
  leadTimeValue: string;
  leadTimeUnit: LeadTimeUnit;
  storageLocation: string;
  stockQuantity: string;
  reorderLevel: string;
  originCountry: string;
  hsCode: string;
  shippingRoute: string;
  transportMode: string;
}

const EMPTY: FormState = {
  name: '', materialType: 'component', supplierId: '', articleNumber: '', description: '',
  unit: 'Stk', unitPrice: '', priceIncludesTax: false, quantity: '1', minOrderQuantity: '1',
  leadTimeValue: '0', leadTimeUnit: 'days', storageLocation: '', stockQuantity: '0',
  reorderLevel: '0', originCountry: '', hsCode: '', shippingRoute: '', transportMode: '',
};

function toForm(material: Material): FormState {
  return {
    name: material.name,
    materialType: material.materialType,
    supplierId: material.supplierId ?? '',
    articleNumber: material.articleNumber ?? '',
    description: material.description ?? '',
    unit: material.unit,
    unitPrice: (material.unitPriceCents / 100).toFixed(2),
    priceIncludesTax: material.priceIncludesTax,
    quantity: String(material.quantity),
    minOrderQuantity: String(material.minOrderQuantity),
    leadTimeValue: String(material.leadTimeValue),
    leadTimeUnit: material.leadTimeUnit,
    storageLocation: material.storageLocation ?? '',
    stockQuantity: String(material.stockQuantity),
    reorderLevel: String(material.reorderLevel),
    originCountry: material.riskProfile?.originCountry ?? '',
    hsCode: material.riskProfile?.hsCode ?? '',
    shippingRoute: material.riskProfile?.shippingRoute ?? '',
    transportMode: material.riskProfile?.transportMode ?? '',
  };
}

function MaterialCardView({
  material, onEdit, onDelete, onRefreshRisk, refreshing, onManual,
}: {
  material: Material;
  onEdit: () => void;
  onDelete: () => void;
  onRefreshRisk: () => void;
  refreshing: boolean;
  onManual: () => void;
}) {
  return (
    <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
          <Typography variant="subtitle1" fontWeight={600}>{material.name}</Typography>
          <RiskAmpel
            level={material.riskLevel}
            score={material.riskScore}
            showScore={false}
            tooltip={
              material.riskScore !== null
                ? `Score ${material.riskScore} (${levelForScore(material.riskScore)})`
                : 'Keine Risikodaten'
            }
          />
        </Stack>
        <Typography variant="body2" color="text.secondary">
          {material.supplierName ?? 'Ohne Lieferanten'}
          {material.articleNumber ? ` · ${material.articleNumber}` : ''}
        </Typography>
        <Stack spacing={0.5} sx={{ mt: 1.5 }}>
          <Typography variant="body2">
            Preis: {formatMoney(material.unitPriceCents, material.currency)} / {material.unit}
          </Typography>
          <Typography variant="body2">
            Lieferzeit: {formatLeadTime(material.leadTimeValue, material.leadTimeUnit)}
          </Typography>
          <Typography variant="body2">
            Bestand: {formatNumber(material.stockQuantity)}
            {material.reorderLevel > 0 && material.stockQuantity < material.reorderLevel
              ? ' ⚠ unter Meldebestand'
              : ''}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Herkunft: {material.riskProfile?.originCountry ?? '–'}
            {material.riskProfile?.isSingleSource ? ' · Single Source' : ''}
          </Typography>
        </Stack>
      </CardContent>
      <CardActions>
        <Button size="small" onClick={onEdit}>Bearbeiten</Button>
        <Tooltip title="Risikodaten neu laden (Hintergrundjob)">
          <Button size="small" onClick={onRefreshRisk} disabled={refreshing}>
            {refreshing ? '…' : 'Risiko refresh'}
          </Button>
        </Tooltip>
        <Button size="small" onClick={onManual}>Ampel</Button>
        <Box sx={{ flexGrow: 1 }} />
        <IconButton size="small" color="error" aria-label="Löschen" onClick={onDelete}>
          ✕
        </IconButton>
      </CardActions>
    </Card>
  );
}

export function MaterialTab({ projectId }: { projectId: string }) {
  const materials = useMaterials(projectId);
  const suppliers = useSuppliers(projectId);
  const leadTime = useLeadTimeAnalysis(projectId);
  const mutations = useMaterialMutations(projectId);
  const refresh = useMutation({ mutationFn: (id: string) => riskApi.refresh(id) });
  const manual = useMutation({
    mutationFn: ({ id, level, note }: { id: string; level: string; note?: string }) =>
      riskApi.manual(id, { level: level as 'green' | 'yellow' | 'red', note }),
  });

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Material | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [manualFor, setManualFor] = useState<Material | null>(null);
  const [manualLevel, setManualLevel] = useState<'green' | 'yellow' | 'red'>('yellow');
  const [manualNote, setManualNote] = useState('');

  const set = (patch: Partial<FormState>) => setForm((prev) => ({ ...prev, ...patch }));

  const openCreate = () => {
    setEditing(null);
    setForm(EMPTY);
    setDialogOpen(true);
  };
  const openEdit = (material: Material) => {
    setEditing(material);
    setForm(toForm(material));
    setDialogOpen(true);
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    const payload = {
      name: form.name,
      materialType: form.materialType,
      supplierId: form.supplierId || null,
      articleNumber: form.articleNumber || null,
      description: form.description || null,
      unit: form.unit,
      unitPriceCents: Math.round(Number(form.unitPrice.replace(',', '.')) * 100),
      priceIncludesTax: form.priceIncludesTax,
      quantity: Number(form.quantity) || 1,
      minOrderQuantity: Number(form.minOrderQuantity) || 1,
      leadTimeValue: Number(form.leadTimeValue) || 0,
      leadTimeUnit: form.leadTimeUnit,
      storageLocation: form.storageLocation || null,
      stockQuantity: Number(form.stockQuantity) || 0,
      reorderLevel: Number(form.reorderLevel) || 0,
      riskProfile: {
        originCountry: form.originCountry || null,
        hsCode: form.hsCode || null,
        shippingRoute: form.shippingRoute || null,
        transportMode: (form.transportMode || null) as TransportMode | null,
      },
    };
    if (editing) {
      mutations.update.mutate(
        { id: editing.id, material: payload },
        { onSuccess: () => setDialogOpen(false) },
      );
    } else {
      mutations.create.mutate(payload, { onSuccess: () => setDialogOpen(false) });
    }
  };

  if (materials.isLoading) return <LoadingState label="Materialien werden geladen …" />;
  if (materials.isError) return <QueryError error={materials.error} />;

  const rows = materials.data?.data ?? [];

  return (
    <Stack spacing={2}>
      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack direction="row" spacing={2} alignItems="center" flexWrap="wrap" useFlexGap>
          <Typography variant="subtitle2" sx={{ mr: 1 }}>Lieferzeiten</Typography>
          <Chip size="small" label={`Ø geplant: ${formatNumber(leadTime.data?.averagePlannedDays, 1)} Tage`} />
          <Chip size="small" color="warning" label={`Längste: ${formatNumber(leadTime.data?.longestDays, 0)} Tage`} />
          <Chip
            size="small" color="info"
            label={`Risikogewichtet: ${formatNumber(leadTime.data?.riskWeightedAverageDays, 1)} Tage`}
          />
          {leadTime.data && leadTime.data.varianceDays !== null && (
            <Chip
              size="small"
              color={Math.abs(leadTime.data.varianceDays) > 3 ? 'warning' : 'default'}
              label={`Abweichung: ${leadTime.data.varianceDays > 0 ? '+' : ''}${leadTime.data.varianceDays} Tage`}
            />
          )}
          <Box sx={{ flexGrow: 1 }} />
          <Button variant="contained" onClick={openCreate}>Neues Material</Button>
        </Stack>
      </Paper>

      {rows.length === 0 ? (
        <EmptyState
          title="Noch keine Materialien"
          hint="Lege das erste Material an, um die Kalkulation zu starten."
          action={
            <Button variant="contained" onClick={openCreate}>Material anlegen</Button>
          }
        />
      ) : (
        <Grid container spacing={2}>
          {rows.map((material) => (
            <Grid size={{ xs: 12, sm: 6, lg: 4 }} key={material.id}>
              <MaterialCardView
                material={material}
                onEdit={() => openEdit(material)}
                onDelete={() => mutations.remove.mutate(material.id)}
                onRefreshRisk={() => refresh.mutate(material.id)}
                refreshing={refresh.isPending && refresh.variables === material.id}
                onManual={() => setManualFor(material)}
              />
            </Grid>
          ))}
        </Grid>
      )}

      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>{editing ? 'Material bearbeiten' : 'Neues Material'}</DialogTitle>
        <form onSubmit={submit}>
          <DialogContent dividers>
            <Grid container spacing={2}>
              <Grid size={{ xs: 12, sm: 8 }}>
                <TextField label="Materialname" required fullWidth value={form.name}
                  onChange={(e) => set({ name: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 12, sm: 4 }}>
                <TextField select fullWidth label="Typ" value={form.materialType}
                  onChange={(e) => set({ materialType: e.target.value as MaterialType })}>
                  {TYPES.map((t) => (
                    <MenuItem key={t.value} value={t.value}>{t.label}</MenuItem>
                  ))}
                </TextField>
              </Grid>
              <Grid size={{ xs: 12, sm: 6 }}>
                <FormControl fullWidth>
                  <InputLabel>Lieferant</InputLabel>
                  <Select label="Lieferant" value={form.supplierId}
                    onChange={(e) => set({ supplierId: e.target.value })}>
                    <MenuItem value="">– ohne –</MenuItem>
                    {(suppliers.data?.data ?? []).map((supplier) => (
                      <MenuItem key={supplier.id} value={supplier.id}>{supplier.name}</MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
              <Grid size={{ xs: 12, sm: 6 }}>
                <TextField label="Artikelnummer" fullWidth value={form.articleNumber}
                  onChange={(e) => set({ articleNumber: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 6, sm: 4 }}>
                <TextField label={`Preis (${form.priceIncludesTax ? 'brutto' : 'netto'})`} fullWidth
                  value={form.unitPrice} onChange={(e) => set({ unitPrice: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 6, sm: 4 }}>
                <FormControlLabel control={
                  <Checkbox checked={form.priceIncludesTax}
                    onChange={(e) => set({ priceIncludesTax: e.target.checked })} />
                } label="Preis ist brutto" />
              </Grid>
              <Grid size={{ xs: 6, sm: 4 }}>
                <TextField label="Einheit" fullWidth value={form.unit}
                  onChange={(e) => set({ unit: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 4 }}>
                <TextField label="Anzahl" fullWidth value={form.quantity}
                  onChange={(e) => set({ quantity: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 4 }}>
                <TextField label="Mindestabnahme" fullWidth value={form.minOrderQuantity}
                  onChange={(e) => set({ minOrderQuantity: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 4 }}>
                <TextField label="Lagerort" fullWidth value={form.storageLocation}
                  onChange={(e) => set({ storageLocation: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 4 }}>
                <TextField label="Lieferzeit" fullWidth value={form.leadTimeValue}
                  onChange={(e) => set({ leadTimeValue: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 4 }}>
                <TextField select fullWidth label="Einheit" value={form.leadTimeUnit}
                  onChange={(e) => set({ leadTimeUnit: e.target.value as LeadTimeUnit })}>
                  {UNITS.map((u) => (
                    <MenuItem key={u.value} value={u.value}>{u.label}</MenuItem>
                  ))}
                </TextField>
              </Grid>
              <Grid size={{ xs: 2 }}>
                <TextField label="Bestand" fullWidth value={form.stockQuantity}
                  onChange={(e) => set({ stockQuantity: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 2 }}>
                <TextField label="Meldebestand" fullWidth value={form.reorderLevel}
                  onChange={(e) => set({ reorderLevel: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 12 }}>
                <Typography variant="subtitle2" sx={{ mt: 1 }}>Lieferrisiko (optional)</Typography>
              </Grid>
              <Grid size={{ xs: 3 }}>
                <TextField label="Herkunftsland" fullWidth placeholder="DE" value={form.originCountry}
                  onChange={(e) => set({ originCountry: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 3 }}>
                <TextField label="HS-Code" fullWidth value={form.hsCode}
                  onChange={(e) => set({ hsCode: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 3 }}>
                <TextField label="Versandroute" fullWidth value={form.shippingRoute}
                  onChange={(e) => set({ shippingRoute: e.target.value })} />
              </Grid>
              <Grid size={{ xs: 3 }}>
                <TextField select fullWidth label="Transport" value={form.transportMode}
                  onChange={(e) => set({ transportMode: e.target.value })}>
                  <MenuItem value="">–</MenuItem>
                  {TRANSPORT.map((t) => (
                    <MenuItem key={t.value} value={t.value}>{t.label}</MenuItem>
                  ))}
                </TextField>
              </Grid>
            </Grid>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setDialogOpen(false)}>Abbrechen</Button>
            <Button type="submit" variant="contained"
              disabled={mutations.create.isPending || mutations.update.isPending}>
              {editing ? 'Speichern' : 'Anlegen'}
            </Button>
          </DialogActions>
        </form>
      </Dialog>

      <Dialog open={Boolean(manualFor)} onClose={() => setManualFor(null)}>
        <DialogTitle>Manuelle Risikoeinschätzung</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1, minWidth: 320 }}>
            <Alert severity="info" variant="outlined">
              Die manuelle Einschätzung wird als Quelle „manual“ protokolliert und bleibt von
              automatischen Providerwerten unterscheidbar.
            </Alert>
            <TextField select label="Ampel" value={manualLevel}
              onChange={(e) => setManualLevel(e.target.value as 'green' | 'yellow' | 'red')}>
              <MenuItem value="green">🟢 Niedrig</MenuItem>
              <MenuItem value="yellow">🟡 Mittel</MenuItem>
              <MenuItem value="red">🔴 Hoch</MenuItem>
            </TextField>
            <TextField label="Notiz" multiline minRows={2} value={manualNote}
              onChange={(e) => setManualNote(e.target.value)} />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setManualFor(null)}>Abbrechen</Button>
          <Button variant="contained" onClick={() => {
            if (!manualFor) return;
            manual.mutate(
              { id: manualFor.id, level: manualLevel, note: manualNote || undefined },
              { onSuccess: () => { setManualFor(null); setManualNote(''); void materials.refetch(); } },
            );
          }}>
            Übernehmen
          </Button>
        </DialogActions>
      </Dialog>
      {refresh.isError && <Alert severity="error">{errorMessage(refresh.error)}</Alert>}
      {manual.isError && <Alert severity="error">{errorMessage(manual.error)}</Alert>}
      {mutations.remove.isError && <Alert severity="error">{errorMessage(mutations.remove.error)}</Alert>}
    </Stack>
  );
}
