import {
  Alert, Box, Button, Card, CardContent, Chip, Grid, Paper, Stack,
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TextField,
  ToggleButton, ToggleButtonGroup, Typography,
} from '@mui/material';
import { useState } from 'react';
import { EmptyState } from '../../../shared/components/EmptyState';
import { LoadingState } from '../../../shared/components/LoadingState';
import { QueryError } from '../../../shared/components/QueryError';
import { RiskAmpel } from '../../../shared/components/RiskAmpel';
import { formatMoney, parseAmountToCents, formatPercent } from '../../../shared/lib/money';
import { errorMessage } from '../../../shared/lib/errors';
import type { PriceOptimizationResult, PricingScenario } from '../../../shared/api/types';
import {
  usePricing, usePricingScenarios, usePriceOptimizer,
  useScenarioMutations, useProject,
} from '../api/queries';

export function PricingTab({ projectId }: { projectId: string }) {
  const pricing = usePricing(projectId);
  const scenarios = usePricingScenarios(projectId);
  const project = useProject(projectId);
  const optimizer = usePriceOptimizer(projectId);
  const scenarioMutations = useScenarioMutations(projectId);

  const [targetInput, setTargetInput] = useState('');
  const [includesTax, setIncludesTax] = useState(true);

  if (pricing.isLoading || project.isLoading) {
    return <LoadingState label="Kalkulation wird geladen …" />;
  }
  if (pricing.isError) return <QueryError error={pricing.error} />;

  const result = pricing.data;
  const scenarioRows: PricingScenario[] = scenarios.data?.data ?? [];
  const optimization: PriceOptimizationResult | null = optimizer.data ?? null;

  const runOptimize = () => {
    const cents = parseAmountToCents(targetInput);
    if (cents === null) return;
    optimizer.mutate({
      targetPriceCents: cents,
      targetPriceIncludesTax: includesTax,
      unitsPerMonth: project.data?.unitsPerMonth ?? 100,
      batchSize: project.data?.batchSize ?? 1,
    });
  };

  if (!result) {
    return <EmptyState title="Keine Kalkulation" hint="Es liegen keine Kostendaten vor." />;
  }

  const totals = result.totals;

  return (
    <Stack spacing={3}>
      <Grid container spacing={2}>
        <Grid size={{ xs: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Typography variant="body2" color="text.secondary">Gesamtkosten netto</Typography>
              <Typography variant="h6">{formatMoney(totals.totalCostNetCents)}</Typography>
              <Typography variant="body2" color="text.secondary">
                Brutto: {formatMoney(totals.totalCostGrossCents)}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Typography variant="body2" color="text.secondary">Kosten pro Stück netto</Typography>
              <Typography variant="h6">{formatMoney(totals.perUnitNetCents)}</Typography>
              <Typography variant="body2" color="text.secondary">
                Brutto: {formatMoney(totals.perUnitGrossCents)}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Typography variant="body2" color="text.secondary">Steuern ({formatPercent(result.inputs.taxRate)})</Typography>
              <Typography variant="h6">{formatMoney(totals.taxCents)}</Typography>
              <Typography variant="body2" color="text.secondary">
                Profil: {result.taxes.taxProfile} · {result.taxes.country}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Typography variant="body2" color="text.secondary">Lieferrisiko</Typography>
              <RiskAmpel level={result.risk.level} score={result.risk.aggregateScore} />
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                Aufschlag: {formatPercent(result.risk.appliedSurchargePct)} · {' '}
                {formatMoney(totals.riskSurchargeCents)}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Kostenblock</TableCell>
              <TableCell align="right">Gesamt</TableCell>
              <TableCell align="right">Pro Einheit</TableCell>
              <TableCell align="right">Anteil</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {result.lines.map((line) => (
              <TableRow key={line.key}>
                <TableCell>{line.label}</TableCell>
                <TableCell align="right">{formatMoney(line.totalCents)}</TableCell>
                <TableCell align="right">{formatMoney(line.perUnitCents)}</TableCell>
                <TableCell align="right">{formatPercent(line.share, 'de-DE', 1)}</TableCell>
              </TableRow>
            ))}
            <TableRow>
              <TableCell sx={{ fontWeight: 600 }}>Gesamtkosten netto</TableCell>
              <TableCell align="right" sx={{ fontWeight: 600 }}>
                {formatMoney(totals.totalCostNetCents)}
              </TableCell>
              <TableCell align="right" sx={{ fontWeight: 600 }}>
                {formatMoney(totals.perUnitNetCents)}
              </TableCell>
              <TableCell align="right">100 %</TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </TableContainer>

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Typography variant="subtitle1" gutterBottom>Manuelle Preisoptimierung</Typography>
        <Stack direction="row" spacing={2} alignItems="center" flexWrap="wrap" useFlexGap>
          <TextField
            label="Zielpreis (€)" size="small" value={targetInput}
            onChange={(event) => setTargetInput(event.target.value)}
            sx={{ width: 160 }}
          />
          <ToggleButtonGroup
            size="small"
            exclusive
            value={includesTax ? 'gross' : 'net'}
            onChange={(_, value) => setIncludesTax(value !== 'net')}
          >
            <ToggleButton value="net">Netto</ToggleButton>
            <ToggleButton value="gross">Brutto</ToggleButton>
          </ToggleButtonGroup>
          <Button
            variant="contained"
            onClick={runOptimize}
            disabled={optimizer.isPending || parseAmountToCents(targetInput) === null}
          >
            Berechnen
          </Button>
          <Box sx={{ flexGrow: 1 }} />
          <Button
            onClick={() => {
              const cents = parseAmountToCents(targetInput);
              if (cents === null) return;
              scenarioMutations.create.mutate({
                name: `Szenario ${new Date().toLocaleDateString('de-DE')}`,
                targetPriceCents: cents,
                targetPriceIncludesTax: includesTax,
                unitsPerMonth: project.data?.unitsPerMonth ?? 100,
              });
            }}
            disabled={scenarioMutations.create.isPending || parseAmountToCents(targetInput) === null}
          >
            Als Szenario speichern
          </Button>
        </Stack>

        {optimizer.isPending && <LoadingState label="Berechne Zielpreis …" />}
        {optimizer.isError && (
          <Alert severity="error" sx={{ mt: 2 }}>{errorMessage(optimizer.error)}</Alert>
        )}
        {optimization && (
          <Box sx={{ mt: 2 }}>
            <Grid container spacing={2}>
              <Grid size={{ xs: 12, md: 6 }}>
                <TableContainer component={Paper} variant="outlined">
                  <Table size="small">
                    <TableBody>
                      <TableRow>
                        <TableCell>Zielpreis</TableCell>
                        <TableCell align="right">
                          {formatMoney(optimization.target.netCents)} netto
                          {' / '}
                          {formatMoney(optimization.target.grossCents)} brutto
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell>Kalkuliert (ohne Zielpreis)</TableCell>
                        <TableCell align="right">
                          {formatMoney(optimization.calculated.netCents)} netto
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell>Gewinn pro Stück</TableCell>
                        <TableCell align="right">
                          {formatMoney(optimization.profit.perUnitNetCents)} netto
                          {' / '}
                          {formatMoney(optimization.profit.perUnitGrossCents)} brutto
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell>Gewinnmarge</TableCell>
                        <TableCell align="right">{formatPercent(optimization.profit.marginPct)}</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell>Deckungsbeitrag pro Stück</TableCell>
                        <TableCell align="right">
                          {formatMoney(optimization.profit.contributionMarginPerUnitCents)}
                        </TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </TableContainer>
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <TableContainer component={Paper} variant="outlined">
                  <Table size="small">
                    <TableBody>
                      <TableRow>
                        <TableCell>Umsatz / Monat (netto)</TableCell>
                        <TableCell align="right">{formatMoney(optimization.revenue.monthlyNetCents)}</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell>Monatsgewinn (netto)</TableCell>
                        <TableCell align="right">{formatMoney(optimization.monthlyProfit.netCents)}</TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell>Break-Even</TableCell>
                        <TableCell align="right">
                          {optimization.breakEven.unitsPerMonth === null
                            ? 'Nicht erreichbar'
                            : `${optimization.breakEven.unitsPerMonth} Stück/Monat`}
                        </TableCell>
                      </TableRow>
                    </TableBody>
                  </Table>
                </TableContainer>
                {optimization.warnings.length > 0 && (
                  <Alert severity="warning" sx={{ mt: 1 }}>
                    {optimization.warnings.join(' · ')}
                  </Alert>
                )}
              </Grid>
            </Grid>
          </Box>
        )}

      </Paper>

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Typography variant="subtitle1" gutterBottom>Preisszenarien</Typography>
        {scenarioRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            Noch keine Szenarien gespeichert.
          </Typography>
        ) : (
          <Stack spacing={1}>
            {scenarioRows.map((scenario) => (
              <Stack
                key={scenario.id}
                direction="row"
                alignItems="center"
                spacing={2}
                sx={{
                  border: '1px solid #e3e7ec', borderRadius: 1, px: 2, py: 1,
                  bgcolor: scenario.isActive ? 'action.selected' : 'transparent',
                }}
              >
                <Typography variant="body2" sx={{ minWidth: 180 }}>{scenario.name}</Typography>
                <Chip
                  size="small"
                  label={
                    scenario.targetPriceCents
                      ? `Ziel: ${formatMoney(scenario.targetPriceCents)}${scenario.targetPriceIncludesTax ? ' brutto' : ' netto'}`
                      : 'Kein Zielpreis'
                  }
                />
                <Box sx={{ flexGrow: 1 }} />
                <Button
                  size="small"
                  disabled={scenario.isActive}
                  onClick={() => scenarioMutations.activate.mutate(scenario.id)}
                >
                  {scenario.isActive ? 'Aktiv' : 'Aktivieren'}
                </Button>
              </Stack>
            ))}
          </Stack>
        )}
        {scenarioMutations.create.isError && (
          <Alert severity="error" sx={{ mt: 1 }}>
            {errorMessage(scenarioMutations.create.error)}
          </Alert>
        )}
      </Paper>

      <Typography variant="caption" color="text.secondary">
        MwSt.-Satz: {formatPercent(project.data?.taxRate ?? 0.19)} — zentral in den
        Projekteinstellungen (Steuerverwaltung) pflegbar.
      </Typography>
    </Stack>
  );
}
