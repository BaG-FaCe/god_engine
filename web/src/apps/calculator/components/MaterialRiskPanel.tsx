import { Alert, Box, Chip, LinearProgress, Stack, Typography } from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { riskApi } from '../api/risk';
import { RiskAmpel } from '../../../shared/components/RiskAmpel';
import type { MaterialRiskView } from '../../../shared/api/types';

const DIMENSION_LABELS: Record<string, string> = {
  logistics: 'Logistik',
  geopolitical: 'Geopolitisch',
  weather: 'Wetter',
  financial: 'Finanziell',
  compliance: 'Compliance',
  operational: 'Operativ',
};

/**
 * Collapsed-by-default "Lieferrisiko" detail section of a material card
 * (Update-Prompt Aufgabe 2: Deep-Link zielt auf diesen aufgeklappten Bereich).
 */
export function MaterialRiskPanel({ materialId }: { materialId: string }) {
  const { data, isLoading, isError } = useQuery({
    queryKey: ['calculator', 'material-risk', materialId],
    queryFn: () => riskApi.assessment(materialId),
    enabled: Boolean(materialId),
  });

  if (isLoading) return <LinearProgress />;
  if (isError || !data) {
    return <Alert severity="warning" variant="outlined">Risikodaten konnten nicht geladen werden.</Alert>;
  }

  return <RiskPanelContent view={data} />;
}

function RiskPanelContent({ view }: { view: MaterialRiskView }) {
  const dimensions = Object.entries(view.dimensions ?? {}).filter(
    ([, value]) => value !== null && value !== undefined,
  ) as Array<[string, number]>;

  return (
    <Stack spacing={1.5} sx={{ px: 2, pb: 2 }}>
      <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
        <RiskAmpel level={view.riskLevel} score={view.riskScore} />
        {view.sanctionsStatus === 'flagged' && (
          <Chip size="small" color="error" label="Sanktionshinweis" />
        )}
        {view.hasManualData && <Chip size="small" label="manuell bewertet" />}
      </Stack>

      {dimensions.length > 0 && (
        <Stack spacing={0.5}>
          <Typography variant="caption" color="text.secondary">Risikodimensionen</Typography>
          {dimensions.map(([key, value]) => (
            <Box key={key} sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Typography variant="caption" sx={{ width: 96 }}>
                {DIMENSION_LABELS[key] ?? key}
              </Typography>
              <LinearProgress
                variant="determinate"
                value={value}
                sx={{ flexGrow: 1, height: 6, borderRadius: 3 }}
                color={value >= 67 ? 'error' : value >= 34 ? 'warning' : 'success'}
              />
              <Typography variant="caption" sx={{ width: 28, textAlign: 'right' }}>{value}</Typography>
            </Box>
          ))}
        </Stack>
      )}

      {view.lastEvent && (
        <Typography variant="caption" color="text.secondary">
          Letztes Ereignis: {view.lastEvent.title}
        </Typography>
      )}
      {view.dataSources.length > 0 && (
        <Typography variant="caption" color="text.secondary">
          Quellen: {view.dataSources.join(', ')}
        </Typography>
      )}
    </Stack>
  );
}
