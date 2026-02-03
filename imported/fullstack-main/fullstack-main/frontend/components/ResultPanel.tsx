import React from "react";
import { ScreeningResult, PatientData, CBCRow } from "../types";
import { CheckCircle, AlertTriangle, AlertOctagon } from "lucide-react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  Cell,
  LabelList,
} from "recharts";

interface Props {
  result: ScreeningResult;
  patient: PatientData;
  cbcRows: CBCRow[];
}

const ResultPanel: React.FC<Props> = ({ result }) => {
  // -------------------------------
  // SINGLE SOURCE OF TRUTH: Use backend's label (argmax of probabilities)
  // -------------------------------
  const pN = result.probabilities.normal;
  const pB = result.probabilities.borderline;
  const pD = result.probabilities.deficient;

  // Map backend label (uppercase) to display format
  const labelMap: Record<string, "Normal" | "Borderline" | "Deficient"> = {
    NORMAL: "Normal",
    BORDERLINE: "Borderline",
    DEFICIENT: "Deficient",
  };
  const finalLabel = labelMap[result.label] ?? "Normal";

  // -------------------------------
  // BADGE
  // -------------------------------
  const badge = () => {
    const breakdown = (
      <div className="text-xs mt-1 font-medium">
        N: {(pN * 100).toFixed(1)}% | B: {(pB * 100).toFixed(1)}% | D:{" "}
        {(pD * 100).toFixed(1)}%
      </div>
    );

    if (finalLabel === "Deficient")
      return (
        <div className="bg-red-50 border border-red-200 p-4 rounded flex gap-3">
          <AlertOctagon className="text-red-600" />
          <div>
            <h3 className="font-bold text-red-700">
              High Risk (Deficiency)
            </h3>
            {breakdown}
          </div>
        </div>
      );

    if (finalLabel === "Borderline")
      return (
        <div className="bg-amber-50 border border-amber-200 p-4 rounded flex gap-3">
          <AlertTriangle className="text-amber-600" />
          <div>
            <h3 className="font-bold text-amber-700">
              Borderline / Indeterminate
            </h3>
            {breakdown}
          </div>
        </div>
      );

    return (
      <div className="bg-green-50 border border-green-200 p-4 rounded flex gap-3">
        <CheckCircle className="text-green-600" />
        <div>
          <h3 className="font-bold text-green-700">Low Risk (Normal)</h3>
          {breakdown}
        </div>
      </div>
    );
  };

  // -------------------------------
  // CHART DATA
  // -------------------------------
  const chartData = [
    { name: "Normal", value: +(pN * 100).toFixed(1) },
    { name: "Borderline", value: +(pB * 100).toFixed(1) },
    { name: "Deficient", value: +(pD * 100).toFixed(1) },
  ];

  const colors = ["#22c55e", "#f59e0b", "#ef4444"];

  // -------------------------------
  // UI
  // -------------------------------
  return (
    <div className="bg-white border p-5 rounded space-y-6">
      <h2 className="text-lg font-bold">Screening Analysis Report</h2>

      {badge()}

      {/* Chart */}
      <div className="border rounded p-4">
        <h4 className="text-xs text-center mb-4 uppercase font-semibold">
          Model Confidence Probabilities
        </h4>

        <div className="h-48">
          <ResponsiveContainer>
            <BarChart layout="vertical" data={chartData}>
              <XAxis type="number" domain={[0, 100]} hide />
              <YAxis type="category" dataKey="name" />
              <Tooltip />

              <Bar dataKey="value" barSize={22}>
                <LabelList
                  dataKey="value"
                  position="right"
                  formatter={(v: number) => `${v}%`}
                />
                {chartData.map((_, i) => (
                  <Cell key={i} fill={colors[i]} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Interpretation */}
      <div className="bg-slate-50 p-4 rounded">
        <h4 className="font-semibold mb-2">Clinical Interpretation</h4>
        <p className="italic text-sm">{result.interpretation}</p>
      </div>

      {/* Recommendation */}
      <div className="bg-blue-50 p-4 rounded">
        <h4 className="font-semibold mb-2">Recommendation</h4>
        <p className="text-sm">{result.recommendation}</p>
      </div>
    </div>
  );
};

export default ResultPanel;
