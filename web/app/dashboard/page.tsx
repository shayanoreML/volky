'use client';

import { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export default function Dashboard() {
  const [metrics, setMetrics] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // TODO: Fetch from CloudKit JS API
    fetchMetrics();
  }, []);

  async function fetchMetrics() {
    // Placeholder - will integrate with CloudKit JS
    const mockData = [
      { date: '2025-01-01', clarityScore: 65, lesionCount: 12 },
      { date: '2025-01-08', clarityScore: 70, lesionCount: 10 },
      { date: '2025-01-15', clarityScore: 75, lesionCount: 8 },
      { date: '2025-01-22', clarityScore: 78, lesionCount: 7 },
      { date: '2025-01-29', clarityScore: 82, lesionCount: 5 },
    ];

    setMetrics(mockData);
    setLoading(false);
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-canvas flex items-center justify-center">
        <div className="text-textSecondary">Loading...</div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-canvas">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-textPrimary font-heading mb-2">
            Dashboard
          </h1>
          <p className="text-textSecondary">
            View your skin progress over time
          </p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <StatCard
            label="Clarity Score"
            value={metrics[metrics.length - 1]?.clarityScore || 0}
            trend="+5%"
            trendUp={true}
          />
          <StatCard
            label="Active Lesions"
            value={metrics[metrics.length - 1]?.lesionCount || 0}
            trend="-3"
            trendUp={true}
          />
          <StatCard
            label="Total Scans"
            value={metrics.length}
            trend="+5 this week"
            trendUp={true}
          />
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Clarity Score Chart */}
          <div className="bg-surface rounded-card p-6 shadow-card">
            <h2 className="text-xl font-semibold text-textPrimary mb-4 font-heading">
              Clarity Score Trend
            </h2>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={metrics}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                <XAxis dataKey="date" stroke="#374151" />
                <YAxis stroke="#374151" />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#ECF2F7',
                    border: 'none',
                    borderRadius: '12px',
                  }}
                />
                <Line
                  type="monotone"
                  dataKey="clarityScore"
                  stroke="#69E3C6"
                  strokeWidth={2}
                  dot={{ fill: '#69E3C6', r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>

          {/* Lesion Count Chart */}
          <div className="bg-surface rounded-card p-6 shadow-card">
            <h2 className="text-xl font-semibold text-textPrimary mb-4 font-heading">
              Lesion Count Trend
            </h2>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={metrics}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                <XAxis dataKey="date" stroke="#374151" />
                <YAxis stroke="#374151" />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#ECF2F7',
                    border: 'none',
                    borderRadius: '12px',
                  }}
                />
                <Line
                  type="monotone"
                  dataKey="lesionCount"
                  stroke="#6AB7FF"
                  strokeWidth={2}
                  dot={{ fill: '#6AB7FF', r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Call to Action */}
        <div className="mt-8 bg-surface rounded-card p-8 shadow-card text-center">
          <h3 className="text-2xl font-semibold text-textPrimary mb-4 font-heading">
            Open on iPhone to Scan
          </h3>
          <p className="text-textSecondary mb-6">
            New scans can only be captured on your iPhone with TrueDepth camera.
          </p>
          <button className="bg-mint text-white px-6 py-3 rounded-button font-semibold hover:opacity-90 transition-opacity">
            Open Volcy App
          </button>
        </div>
      </div>
    </main>
  );
}

function StatCard({ label, value, trend, trendUp }: {
  label: string;
  value: number | string;
  trend: string;
  trendUp: boolean;
}) {
  return (
    <div className="bg-surface rounded-card p-6 shadow-card">
      <div className="text-textSecondary text-sm mb-2">{label}</div>
      <div className="text-3xl font-bold text-textPrimary font-mono mb-2">
        {value}
      </div>
      <div className={`text-sm ${trendUp ? 'text-mint' : 'text-red-500'}`}>
        {trend}
      </div>
    </div>
  );
}
