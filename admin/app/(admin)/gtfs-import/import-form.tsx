"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { FileField, SelectField, TextField } from "@/components/ui/fields";
import { FormCard, FormFooter, FormMessage } from "@/components/ui/form";
import { Notice } from "@/components/ui/notice";
import { importGtfs, type GtfsImportState } from "./actions";

const initialState: GtfsImportState = undefined;

export function GtfsImportForm({
  operators,
}: {
  operators: { id: string; name: string }[];
}) {
  const [state, formAction, pending] = useActionState(importGtfs, initialState);
  const error = state && "error" in state ? state.error : undefined;

  return (
    <FormCard action={formAction} title="Impor feed">
      <SelectField
        label="Operator"
        name="operator_id"
        required
        defaultValue=""
        hint="Lini hasil impor dikaitkan ke operator ini."
      >
        <option value="">Pilih operator</option>
        {operators.map((operator) => (
          <option key={operator.id} value={operator.id}>
            {operator.name}
          </option>
        ))}
      </SelectField>
      <FileField label="Berkas GTFS (.zip)" name="file" accept=".zip" required />
      <TextField
        label="Jumlah hari ke depan yang diimpor"
        name="window_days"
        type="number"
        min={1}
        max={30}
        defaultValue={1}
        required
        fieldClassName="max-w-40"
        hint="calendar.txt dan calendar_dates.txt tidak berulang di skema ini: setiap hari yang dipilih menjadi baris trip bertanggal. Jumlah hari besar dengan banyak trip menghasilkan banyak baris."
      />
      <Notice tone="warn" title="Batas satu request web">
        <p>
          Untuk feed KRL asli (sekitar 86 stasiun, sekitar 984 trip), satu hari
          saja menghasilkan kira-kira 16 ribu baris jadwal. Lebih dari itu
          berisiko melewati batas waktu atau memori satu request Cloudflare
          Workers dan gagal di tengah jalan (halaman ini akan minta dimuat
          ulang).
        </p>
        <p>
          Untuk impor beberapa hari sekaligus, jalankan dari terminal:{" "}
          <code>
            npm run import-gtfs -- &lt;path-zip&gt; &lt;operator-id&gt;
            &lt;jumlah-hari&gt;
          </code>
          . Skrip yang sama dipakai untuk mengisi data asli saat ini dan tidak
          terikat batas request web.
        </p>
      </Notice>
      <FormFooter>
        <Button
          type="submit"
          loading={pending}
          loadingLabel="Mengimpor (bisa puluhan detik)…"
        >
          Impor GTFS
        </Button>
        <FormMessage error={error} />
      </FormFooter>
      {state && "summary" in state && (
        <div role="status">
          <Notice tone="info" title="Impor berhasil">
            <p>
              {state.summary.stopCount} stasiun, {state.summary.routeCount}{" "}
              lini, {state.summary.tripCount} pola trip dari feed menjadi{" "}
              {state.summary.tripInstancesImported} baris trip bertanggal dan{" "}
              {state.summary.stopTimeRowsImported} baris jadwal perhentian
              untuk {state.summary.serviceDaysExpanded} hari ke depan.
            </p>
          </Notice>
        </div>
      )}
    </FormCard>
  );
}
