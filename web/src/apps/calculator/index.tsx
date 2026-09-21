import {
  Alert, Box, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle,
  MenuItem, Paper, Stack, Tab, Tabs, TextField,
} from '@mui/material';
import { useEffect, useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import { LoadingState } from '../../shared/components/LoadingState';
import { QueryError } from '../../shared/components/QueryError';
import { formatMoney } from '../../shared/lib/money';
import type { ProjectUpsert } from '../../shared/api/types';
import {
  useDashboard, useProject, useProjectMutations, useProjects,
} from './api/queries';
import {
  CALCULATOR_TABS, useCalculatorStore,
} from './store/calculator-store';
import { MaterialTab } from './tabs/MaterialTab';
import { MonthlyCostsTab } from './tabs/MonthlyCostsTab';
import { FixedCostsTab } from './tabs/FixedCostsTab';
import { PricingTab } from './tabs/PricingTab';
import { DashboardTab } from './tabs/DashboardTab';

function NewProjectDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const mutations = useProjectMutations();
  const [name, setName] = useState('');
  const [taxRate, setTaxRate] = useState('19');

  const submit = (event: FormEvent) => {
    event.preventDefault();
    const payload: ProjectUpsert = {
      name,
      taxRate: Number(taxRate.replace(',', '.')) || 19,
      status: 'active',
    };
    mutations.create.mutate(payload, { onSuccess: onClose });
  };

  return (
    <Dialog open={open} onClose={onClose}>
      <DialogTitle>Neues Projekt</DialogTitle>
      <form onSubmit={submit}>
        <DialogContent>
          <Stack spacing={2} sx={{ minWidth: 340 }}>
            <TextField label="Projektname" required value={name}
              onChange={(event) => setName(event.target.value)} />
            <TextField label="MwSt.-Satz (%)" value={taxRate}
              onChange={(event) => setTaxRate(event.target.value)} />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={onClose}>Abbrechen</Button>
          <Button type="submit" variant="contained" disabled={mutations.create.isPending}>
            Anlegen
          </Button>
        </DialogActions>
      </form>
    </Dialog>
  );
}

export default function CalculatorPage() {
  const projects = useProjects();
  const store = useCalculatorStore();

  const projectList = projects.data?.data ?? [];
  const activeId = store.projectId && projectList.some((project) => project.id === store.projectId)
    ? store.projectId
    : (projectList[0]?.id ?? null);

  useEffect(() => {
    if (activeId && activeId !== store.projectId) store.selectProject(activeId);
  }, [activeId, store]);

  const project = useProject(activeId);
  const dashboard = useDashboard(activeId);

  const [newOpen, setNewOpen] = useState(false);

  const tab = store.tab;
  const tabValue = useMemo(
    () => CALCULATOR_TABS.findIndex((entry) => entry.key === tab),
    [tab],
  );

  if (projects.isLoading) return <LoadingState label="Projekte werden geladen …" />;
  if (projects.isError) return <QueryError error={projects.error} />;

  if (projectList.length === 0) {
    return (
      <Stack spacing={2}>
        <Alert severity="info">
          Noch kein Projekt vorhanden. Lege dein erstes Kalkulationsprojekt an.
        </Alert>
        <Button variant="contained" onClick={() => setNewOpen(true)} sx={{ alignSelf: 'flex-start' }}>
          Projekt anlegen
        </Button>
        <NewProjectDialog open={newOpen} onClose={() => setNewOpen(false)} />
      </Stack>
    );
  }

  return (
    <Stack spacing={2}>
      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack direction="row" spacing={2} alignItems="center" flexWrap="wrap" useFlexGap>
          <TextField
            select size="small" label="Projekt" sx={{ minWidth: 240 }}
            value={activeId ?? ''}
            onChange={(event) => store.selectProject(event.target.value)}
          >
            {projectList.map((entry) => (
              <MenuItem key={entry.id} value={entry.id}>{entry.name}</MenuItem>
            ))}
          </TextField>
          {project.data && (
            <Chip label={`MwSt. ${project.data.taxRate}%`} size="small" />
          )}
          {dashboard.data && (
            <Chip
              size="small"
              label={`Kosten/Stück: ${formatMoney(dashboard.data.kpis.perUnitNetCents)}`}
            />
          )}
          <Box sx={{ flexGrow: 1 }} />
          <Button size="small" onClick={() => setNewOpen(true)}>+ Projekt</Button>
        </Stack>
      </Paper>

      <Tabs
        value={tabValue < 0 ? 0 : tabValue}
        onChange={(_, index: number) => store.setTab(CALCULATOR_TABS[index].key)}
      >
        {CALCULATOR_TABS.map((entry) => (
          <Tab key={entry.key} label={entry.label} />
        ))}
      </Tabs>

      {project.isError && <QueryError error={project.error} />}

      {activeId && tab === 'materials' && <MaterialTab projectId={activeId} />}
      {activeId && tab === 'monthly' && <MonthlyCostsTab projectId={activeId} />}
      {activeId && tab === 'fixed' && <FixedCostsTab projectId={activeId} />}
      {activeId && tab === 'pricing' && <PricingTab projectId={activeId} />}
      {activeId && tab === 'dashboard' && <DashboardTab projectId={activeId} />}

      <NewProjectDialog open={newOpen} onClose={() => setNewOpen(false)} />
    </Stack>
  );
}

