import {
  Alert, Card, CardContent, Chip, Grid, Paper, Stack, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Typography,
} from '@mui/material';
import {
  Bar, BarChart, CartesianGrid, Cell, Legend, Line, LineChart, Pie, PieChart,
  ResponsiveContainer, Tooltip as ChartTooltip, XAxis, YAxis,
} from 'recharts';
import { LoadingState } from '../../../shared/components/LoadingState';
import { QueryError } from '../../../shared/components/QueryError';
import { RiskAmpel } from '../../../shared/components/RiskAmpel';
import { formatMoney } from '../../../shared/lib/money';
import { formatNumber, formatPeriod } from '../../../shared/lib/format';
import { useDashboard } from '../api/queries';

const RISK_PIE_COLORS: Record<string, string> = {
  low: '#2e7d32',
  medium: '#ed6c02',
  high: '#d32f2f',
  unknown: '#9e9e9e',
};

const PIE_COLORS = ['#1f3a5f', '#0f7b6c', '#ed6c02', '#6a5acd', '#d32f2f', '#00838f'];

const LEVEL_LABELS: Record<string, string> = {
  low: 'Niedrig',
  medium: 'Mittel',
  high: 'Hoch',
  unknown: 'Unbekannt',
};

export function DashboardTab({ projectId }: { projectId: string }) {
  const dashboard = useDashboard(projectId);

  if (dashboard.isLoading) return <LoadingState label="Dashboard wird geladen …" />;
  if (dashboard.isError) return <QueryError error={dashboard.error} />;
  if (!dashboard.data) return null;

  const data = dashboard.data;
  const kpis = data.kpis;

  const kpiCards: Array<{ label: string; value: string; hint?: string }> = [
    { label: 'Materialkosten', value: formatMoney(kpis.materialCostCents) },
    { label: 'Monatliche Kosten', value: formatMoney(kpis.monthlyCostCents) },
    { label: 'Fixkosten', value: formatMoney(kpis.fixedCostCents) },
    { label: 'Arbeitskosten', value: formatMoney(kpis.laborCostCents) },
    { label: 'Gewinn / Stück (netto)', value: formatMoney(kpis.profitPerUnitNetCents) },
    { label: 'Umsatz / Monat (netto)', value: formatMoney(kpis.revenueMonthlyNetCents) },
    {
      label: 'Break-Even',
      value: kpis.breakEvenUnits === null ? '–' : `${formatNumber(kpis.breakEvenUnits)} Stück/Monat`,
    },
    { label: 'Monatsgewinn (netto)', value: formatMoney(kpis.monthlyProfitNetCents) },
  ];

  return (
    <Stack spacing={3}>
      <Grid container spacing={2}>
        {kpiCards.map((kpi) => (
          <Grid size={{ xs: 6, md: 3 }} key={kpi.label}>
            <Card>
              <CardContent>
                <Typography variant="body2" color="text.secondary">{kpi.label}</Typography>
                <Typography variant="h6">{kpi.value}</Typography>
                {kpi.hint && (
                  <Typography variant="caption" color="text.secondary">{kpi.hint}</Typography>
                )}
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack direction="row" spacing={2} alignItems="center" flexWrap="wrap" useFlexGap>
          <Typography variant="subtitle1">Lieferrisiken</Typography>
          <RiskAmpel level={kpis.riskLevel} score={kpis.averageRiskScore} />
          <Chip
            color={kpis.criticalRiskCount > 0 ? 'error' : 'default'}
            label={`Kritische Materialien: ${kpis.criticalRiskCount}`}
          />
          <Chip label={`Bewertete Materialien: ${kpis.materialCount}`} />
        </Stack>
        {data.criticalRiskMaterials.length > 0 && (
          <TableContainer sx={{ mt: 2 }}>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Material</TableCell>
                  <TableCell>Herkunft</TableCell>
                  <TableCell align="right">Score</TableCell>
                  <TableCell>Ampel</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {data.criticalRiskMaterials.map((material) => (
                  <TableRow key={material.materialId}>
                    <TableCell>{material.name}</TableCell>
                    <TableCell>{material.originCountry ?? '–'}</TableCell>
                    <TableCell align="right">{material.riskScore}</TableCell>
                    <TableCell>
                      <RiskAmpel level={material.riskLevel} showScore={false} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </Paper>

      <Grid container spacing={2}>
        <Grid size={{ xs: 12, md: 6 }}>
          <Paper variant="outlined" sx={{ p: 2, height: 320 }}>
            <Typography variant="subtitle2" gutterBottom>Kostenverteilung</Typography>
            <ResponsiveContainer width="100%" height={240}>
              <PieChart>
                <Pie
                  data={data.costDistribution.filter((entry) => entry.totalCents > 0)}
                  dataKey="totalCents"
                  nameKey="label"
                  outerRadius={90}
                >
                  {data.costDistribution.map((entry, index) => (
                    <Cell key={entry.key} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <ChartTooltip formatter={(value) => formatMoney(Number(value))} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </Paper>
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <Paper variant="outlined" sx={{ p: 2, height: 320 }}>
            <Typography variant="subtitle2" gutterBottom>Lieferrisiko-Verteilung</Typography>
            <ResponsiveContainer width="100%" height={240}>
              <BarChart data={data.riskDistribution}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="level"
                  tickFormatter={(value: string) => LEVEL_LABELS[value] ?? value} />
                <YAxis allowDecimals={false} />
                <ChartTooltip />
                <Bar dataKey="count" name="Materialien">
                  {data.riskDistribution.map((entry) => (
                    <Cell key={entry.level} fill={RISK_PIE_COLORS[entry.level] ?? '#9e9e9e'} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </Paper>
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <Paper variant="outlined" sx={{ p: 2, height: 320 }}>
            <Typography variant="subtitle2" gutterBottom>Gewinnentwicklung</Typography>
            {data.profitTrend.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                Keine Prognosedaten vorhanden.
              </Typography>
            ) : (
              <ResponsiveContainer width="100%" height={240}>
                <LineChart data={data.profitTrend}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="period" tickFormatter={(value: string) => formatPeriod(value)} />
                  <YAxis />
                  <ChartTooltip formatter={(value) => formatMoney(Number(value))} />
                  <Legend />
                  <Line type="monotone" dataKey="profitNetCents" name="Gewinn" stroke="#1f3a5f" />
                  <Line type="monotone" dataKey="revenueNetCents" name="Umsatz" stroke="#0f7b6c" />
                </LineChart>
              </ResponsiveContainer>
            )}
          </Paper>
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <Paper variant="outlined" sx={{ p: 2, height: 320 }}>
            <Typography variant="subtitle2" gutterBottom>Risiko-Timeline</Typography>
            {data.riskTimeline.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                Noch keine Risikoverlaufsdaten.
              </Typography>
            ) : (
              <ResponsiveContainer width="100%" height={240}>
                <LineChart data={data.riskTimeline}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis domain={[0, 100]} />
                  <ChartTooltip />
                  <Legend />
                  <Line type="monotone" dataKey="averageRiskScore" name="Ø Risikoscore" stroke="#d32f2f" />
                </LineChart>
              </ResponsiveContainer>
            )}
          </Paper>
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <Paper variant="outlined" sx={{ p: 2, height: 320 }}>
            <Typography variant="subtitle2" gutterBottom>Prognose vs. Realität</Typography>
            {data.forecastVsActual.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                Keine Verkaufsprognosen erfasst.
              </Typography>
            ) : (
              <ResponsiveContainer width="100%" height={240}>
                <BarChart data={data.forecastVsActual}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="period" tickFormatter={(value: string) => formatPeriod(value)} />
                  <YAxis />
                  <ChartTooltip />
                  <Legend />
                  <Bar dataKey="forecastUnits" name="Prognose" fill="#1f3a5f" />
                  <Bar dataKey="actualUnits" name="Tatsächlich" fill="#0f7b6c" />
                </BarChart>
              </ResponsiveContainer>
            )}
          </Paper>
        </Grid>

        <Grid size={{ xs: 12, md: 6 }}>
          <Paper variant="outlined" sx={{ p: 2, height: 320, overflow: 'auto' }}>
            <Typography variant="subtitle2" gutterBottom>Letzte Risiko-Ereignisse</Typography>
            {data.riskEvents.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                Keine Ereignisse gemeldet.
              </Typography>
            ) : (
              <Stack spacing={1}>
                {data.riskEvents.map((event) => (
                  <Alert
                    key={event.id}
                    severity={
                      event.severity === 'critical' || event.severity === 'high'
                        ? 'error'
                        : event.severity === 'medium'
                          ? 'warning'
                          : 'info'
                    }
                  >
                    <strong>{event.title}</strong>
                    <br />
                    <Typography variant="caption">
                      {formatPeriod(event.occurredAt?.slice(0, 7) ?? null)} · Quelle: {event.source}
                    </Typography>
                  </Alert>
                ))}
              </Stack>
            )}
          </Paper>
        </Grid>
      </Grid>
    </Stack>
  );
}

