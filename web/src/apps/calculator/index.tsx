import {
  Alert, Box, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle,
  Menu, MenuItem, Paper, Stack, Tab, Tabs, TextField, Typography,
} from '@mui/material';
import { useEffect, useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import { LoadingState } from '../../shared/components/LoadingState';
import { QueryError } from '../../shared/components/QueryError';
import { formatMoney } from '../../shared/lib/money';
import type { Project, ProjectUpsert } from '../../shared/api/types';
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
import { NotificationBell } from './components/NotificationBell';

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

function ArchiveProjectDialog({
  project, onClose, onConfirm, pending,
}: {
  project: Project | null;
  onClose: () => void;
  onConfirm: () => void;
  pending: boolean;
}) {
  return (
    <Dialog open={Boolean(project)} onClose={onClose}>
      <DialogTitle>Projekt archivieren</DialogTitle>
      <DialogContent>
        <Alert severity="warning">
          „{project?.name}“ wird archiviert und aus der Projektauswahl entfernt.
          Alle Daten bleiben erhalten und können später wiederhergestellt werden.
        </Alert>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Abbrechen</Button>
        <Button variant="contained" color="warning" disabled={pending} onClick={onConfirm}>
          Archivieren
        </Button>
      </DialogActions>
    </Dialog>
  );
}

function DeleteProjectDialog({
  project, onClose, onConfirm, pending,
}: {
  project: Project | null;
  onClose: () => void;
  onConfirm: () => void;
  pending: boolean;
}) {
  const [confirmation, setConfirmation] = useState('');
  const matches = project ? confirmation.trim() === project.name : false;

  return (
    <Dialog open={Boolean(project)} onClose={onClose}>
      <DialogTitle>Projekt endgültig löschen</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ minWidth: 380 }}>
          <Alert severity="error">
            „{project?.name}“ wird samt aller Materialien, Kosten, Szenarien und
            Risikodaten unwiderruflich gelöscht. Das kann nicht rückgängig gemacht werden.
          </Alert>
          <Typography variant="body2">
            Zum Bestätigen bitte den Projektnamen eingeben:{' '}
            <strong>{project?.name}</strong>
          </Typography>
          <TextField
            label="Projektname"
            value={confirmation}
            onChange={(event) => setConfirmation(event.target.value)}
            fullWidth
            autoFocus
          />
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Abbrechen</Button>
        <Button variant="contained" color="error" disabled={!matches || pending} onClick={onConfirm}>
          Endgültig löschen
        </Button>
      </DialogActions>
    </Dialog>
  );
}

export default function CalculatorPage() {
  const projects = useProjects();
  const store = useCalculatorStore();
  const projectMutations = useProjectMutations();

  const projectList = projects.data?.data ?? [];
  // Archived projects are soft-removed: they stay in the database but disappear
  // from the working set (they can be restored via the API / a future view).
  const visibleProjects = useMemo(
    () => projectList.filter((project) => project.status !== 'archived'),
    [projectList],
  );
  const activeId = store.projectId && visibleProjects.some((project) => project.id === store.projectId)
    ? store.projectId
    : (visibleProjects[0]?.id ?? null);

  useEffect(() => {
    if (activeId && activeId !== store.projectId) store.selectProject(activeId);
  }, [activeId, store]);

  const project = useProject(activeId);
  const dashboard = useDashboard(activeId);
  const activeProject = visibleProjects.find((entry) => entry.id === activeId) ?? null;

  const [newOpen, setNewOpen] = useState(false);
  const [menuAnchor, setMenuAnchor] = useState<HTMLElement | null>(null);
  const [archiveTarget, setArchiveTarget] = useState<Project | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Project | null>(null);

  const confirmArchive = () => {
    if (!archiveTarget) return;
    projectMutations.archive.mutate(archiveTarget.id, { onSuccess: () => setArchiveTarget(null) });
  };

  const confirmDelete = () => {
    if (!deleteTarget) return;
    projectMutations.remove.mutate(deleteTarget.id, {
      onSuccess: () => {
        setDeleteTarget(null);
        if (store.projectId === deleteTarget.id) store.selectProject(null);
      },
    });
  };

  const tab = store.tab;
  const tabValue = useMemo(
    () => CALCULATOR_TABS.findIndex((entry) => entry.key === tab),
    [tab],
  );

  if (projects.isLoading) return <LoadingState label="Projekte werden geladen …" />;
  if (projects.isError) return <QueryError error={projects.error} />;

  if (visibleProjects.length === 0) {
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
            {visibleProjects.map((entry) => (
              <MenuItem key={entry.id} value={entry.id}>{entry.name}</MenuItem>
            ))}
          </TextField>
          <Button
            size="small"
            color="inherit"
            disabled={!activeProject}
            onClick={(event) => setMenuAnchor(event.currentTarget)}
          >
            ⋯
          </Button>
          <Menu
            anchorEl={menuAnchor}
            open={Boolean(menuAnchor)}
            onClose={() => setMenuAnchor(null)}
          >
            <MenuItem
              onClick={() => { setArchiveTarget(activeProject); setMenuAnchor(null); }}
            >
              Archivieren
            </MenuItem>
            <MenuItem
              sx={{ color: 'error.main' }}
              onClick={() => { setDeleteTarget(activeProject); setMenuAnchor(null); }}
            >
              Löschen …
            </MenuItem>
          </Menu>
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
          <NotificationBell projectId={activeId} />
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

      <ArchiveProjectDialog
        key={archiveTarget?.id ?? 'archive'}
        project={archiveTarget}
        onClose={() => setArchiveTarget(null)}
        onConfirm={confirmArchive}
        pending={projectMutations.archive.isPending}
      />
      <DeleteProjectDialog
        key={deleteTarget?.id ?? 'delete'}
        project={deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={confirmDelete}
        pending={projectMutations.remove.isPending}
      />
    </Stack>
  );
}

