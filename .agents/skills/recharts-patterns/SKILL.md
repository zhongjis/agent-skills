---
name: recharts-patterns
description: Data visualization patterns using Recharts 3.x - a composable charting library built with React and D3. Use when creating charts, dashboards, or data visualizations in React applications.
---

# Recharts Patterns

Data visualization patterns using Recharts 3.x - a composable charting library built with React and D3.

## Core Chart Types

### Line Chart

```tsx
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";

const data = [
  { date: "2024-01", revenue: 4000, expenses: 2400 },
  { date: "2024-02", revenue: 3000, expenses: 1398 },
];

function RevenueChart() {
  return (
    <ResponsiveContainer width="100%" height={400}>
      <LineChart
        data={data}
        margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
        accessibilityLayer
      >
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="date" />
        <YAxis />
        <Tooltip />
        <Legend />
        <Line
          type="monotone"
          dataKey="revenue"
          stroke="#8884d8"
          strokeWidth={2}
        />
        <Line
          type="monotone"
          dataKey="expenses"
          stroke="#82ca9d"
          strokeDasharray="5 5"
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
```

### Bar Chart

```tsx
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

function SalesChart({ data }: { data: SalesData[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data} accessibilityLayer>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="name" />
        <YAxis />
        <Tooltip />
        <Bar dataKey="sales" fill="#8884d8" radius={[4, 4, 0, 0]} />
        <Bar dataKey="target" fill="#82ca9d" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
```

### Stacked Bar Chart

```tsx
function StackedBarChart({ data }: { data: CategoryData[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data} accessibilityLayer>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="name" />
        <YAxis />
        <Tooltip />
        <Legend />
        <Bar dataKey="desktop" stackId="a" fill="#8884d8" />
        <Bar dataKey="mobile" stackId="a" fill="#82ca9d" />
        <Bar dataKey="tablet" stackId="a" fill="#ffc658" />
      </BarChart>
    </ResponsiveContainer>
  );
}
```

### Pie/Donut Chart

```tsx
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Tooltip,
  Legend,
} from "recharts";

const COLORS = ["#0088FE", "#00C49F", "#FFBB28", "#FF8042"];

function DeviceChart({ data }: { data: { name: string; value: number }[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <PieChart>
        <Pie
          data={data}
          cx="50%"
          cy="50%"
          innerRadius={60}
          outerRadius={100}
          paddingAngle={2}
          dataKey="value"
          label={({ name, percent }) =>
            `${name} ${(percent * 100).toFixed(0)}%`
          }
          labelLine={false}
        >
          {data.map((entry, index) => (
            <Cell key={entry.name} fill={COLORS[index % COLORS.length]} />
          ))}
        </Pie>
        <Tooltip />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  );
}
```

### Area Chart with Gradient

```tsx
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

function TrafficChart({ data }: { data: TrafficData[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <AreaChart data={data} accessibilityLayer>
        <defs>
          <linearGradient id="colorUv" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#8884d8" stopOpacity={0.8} />
            <stop offset="95%" stopColor="#8884d8" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="time" />
        <YAxis />
        <Tooltip />
        <Area
          type="monotone"
          dataKey="visitors"
          stroke="#8884d8"
          fill="url(#colorUv)"
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}
```

### Radar Chart

```tsx
import {
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  Legend,
  ResponsiveContainer,
} from "recharts";

const data = [
  { subject: "Math", A: 120, B: 110 },
  { subject: "Chinese", A: 98, B: 130 },
  { subject: "English", A: 86, B: 130 },
  { subject: "Geography", A: 99, B: 100 },
  { subject: "Physics", A: 85, B: 90 },
  { subject: "History", A: 65, B: 85 },
];

function SkillsRadar() {
  return (
    <ResponsiveContainer width="100%" height={400}>
      <RadarChart cx="50%" cy="50%" outerRadius="80%" data={data}>
        <PolarGrid />
        <PolarAngleAxis dataKey="subject" />
        <PolarRadiusAxis />
        <Radar
          name="Student A"
          dataKey="A"
          stroke="#8884d8"
          fill="#8884d8"
          fillOpacity={0.6}
        />
        <Radar
          name="Student B"
          dataKey="B"
          stroke="#82ca9d"
          fill="#82ca9d"
          fillOpacity={0.6}
        />
        <Legend />
      </RadarChart>
    </ResponsiveContainer>
  );
}
```

### Composed Chart (Mixed Types)

```tsx
import {
  ComposedChart,
  Line,
  Area,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";

function MixedChart({ data }: { data: ComposedData[] }) {
  return (
    <ResponsiveContainer width="100%" height={400}>
      <ComposedChart data={data} accessibilityLayer>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="name" />
        <YAxis />
        <Tooltip />
        <Legend />
        <Area
          type="monotone"
          dataKey="amt"
          fill="#8884d8"
          stroke="#8884d8"
          fillOpacity={0.3}
        />
        <Bar dataKey="pv" barSize={20} fill="#413ea0" />
        <Line type="monotone" dataKey="uv" stroke="#ff7300" />
      </ComposedChart>
    </ResponsiveContainer>
  );
}
```

## Brush (Zoom/Pan)

```tsx
import { Brush } from "recharts";

// Add inside any Cartesian chart (LineChart, BarChart, AreaChart, ComposedChart)
<LineChart data={data} accessibilityLayer>
  <CartesianGrid strokeDasharray="3 3" />
  <XAxis dataKey="name" />
  <YAxis />
  <Tooltip />
  <Line type="monotone" dataKey="value" stroke="#8884d8" />
  <Brush
    dataKey="name"
    height={30}
    stroke="#8884d8"
    startIndex={0}
    endIndex={20}
  />
</LineChart>;
```

## Reference Lines and Areas

Mark thresholds, benchmarks, or highlight zones on Cartesian charts:

```tsx
import { ReferenceLine, ReferenceArea } from "recharts";

// Inside any Cartesian chart (LineChart, BarChart, AreaChart, ComposedChart)
<LineChart data={data} accessibilityLayer>
  <CartesianGrid strokeDasharray="3 3" />
  <XAxis dataKey="name" />
  <YAxis />
  <Tooltip />
  <Line type="monotone" dataKey="value" stroke="#8884d8" />

  {/* Horizontal threshold line */}
  <ReferenceLine
    y={800}
    stroke="#ff4444"
    strokeDasharray="3 3"
    label={{ value: "Target", position: "right" }}
  />

  {/* Vertical event marker */}
  <ReferenceLine
    x="March"
    stroke="#666"
    strokeDasharray="3 3"
    label={{ value: "Launch", position: "top" }}
  />

  {/* Highlighted zone */}
  <ReferenceArea
    x1="Feb"
    x2="Apr"
    y1={200}
    y2={600}
    fill="#8884d8"
    fillOpacity={0.1}
    stroke="#8884d8"
    strokeOpacity={0.3}
    label="Growth Period"
  />
</LineChart>;
```

## Synchronized Charts

Use `syncId` to sync tooltip and brush across multiple charts:

```tsx
function SyncedDashboard({ data }: { data: MetricData[] }) {
  return (
    <div>
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} syncId="dashboard" accessibilityLayer>
          <XAxis dataKey="date" />
          <YAxis />
          <Tooltip />
          <Line type="monotone" dataKey="revenue" stroke="#8884d8" />
        </LineChart>
      </ResponsiveContainer>
      <ResponsiveContainer width="100%" height={200}>
        <AreaChart data={data} syncId="dashboard" accessibilityLayer>
          <XAxis dataKey="date" />
          <YAxis />
          <Tooltip />
          <Area
            type="monotone"
            dataKey="users"
            stroke="#82ca9d"
            fill="#82ca9d"
            fillOpacity={0.3}
          />
          <Brush dataKey="date" height={30} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
```

## Custom Tooltip

```tsx
import { TooltipProps } from "recharts";

function CustomTooltip({
  active,
  payload,
  label,
}: TooltipProps<number, string>) {
  if (!active || !payload?.length) return null;

  return (
    <div className="bg-white p-3 shadow-lg rounded-lg border">
      <p className="font-medium text-gray-900">{label}</p>
      {payload.map((entry) => (
        <p key={entry.name} style={{ color: entry.color }}>
          {entry.name}: {entry.value?.toLocaleString()}
        </p>
      ))}
    </div>
  );
}

// Usage: <Tooltip content={<CustomTooltip />} />
```

### Tooltip Formatter (Inline)

```tsx
// Format values and labels without a custom component
<Tooltip
  formatter={(value: number, name: string) => [
    `$${value.toLocaleString()}`,
    name,
  ]}
  labelFormatter={(label) => `Month: ${label}`}
  cursor={{ stroke: "red", strokeWidth: 2 }}
/>
```

### Tooltip Portal (3.x)

Render the tooltip in a custom DOM container to avoid overflow clipping in scrollable/embedded charts:

```tsx
// Render tooltip outside the chart's SVG container
<Tooltip
  portal={document.getElementById("tooltip-root")}
  wrapperStyle={{ zIndex: 1000 }}
/>

// Useful when chart is inside overflow:hidden containers
// or when tooltip gets clipped by parent boundaries
```

## Accessibility

```tsx
// accessibilityLayer is TRUE by default in Recharts 3.x — explicit prop is optional
<LineChart data={data} accessibilityLayer>

// 2. Wrap in semantic HTML
<figure role="img" aria-label="Monthly revenue trend from January to December">
  <ResponsiveContainer width="100%" height={400}>
    <LineChart data={data} accessibilityLayer>
      <XAxis dataKey="month" />
      <YAxis tickFormatter={(value) => `$${value.toLocaleString()}`} />
      <Tooltip />
      <Line type="monotone" dataKey="revenue" stroke="#8884d8" name="Monthly Revenue" />
    </LineChart>
  </ResponsiveContainer>
  <figcaption className="sr-only">Line chart showing monthly revenue</figcaption>
</figure>

// 3. For screen readers on custom tooltips
<div role="status" aria-live="assertive">{/* tooltip content */}</div>
```

## ResponsiveContainer Patterns

```tsx
// Full-width with fixed height (most common)
<ResponsiveContainer width="100%" height={400}>

// Aspect ratio (auto-height based on width)
<ResponsiveContainer width="100%" aspect={2}>

// Constrained dimensions
<ResponsiveContainer width="100%" minWidth={300} minHeight={200} maxHeight={400}>
```

**Parent must have dimensions** — wrap in a div with explicit height/width.

## Real-Time Updates

```tsx
function RealTimeChart() {
  const { data } = useQuery({
    queryKey: ["metrics"],
    queryFn: fetchMetrics,
    refetchInterval: 5000,
  });

  if (!data) return <ChartSkeleton />;

  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data}>
        <Line
          type="monotone"
          dataKey="value"
          stroke="#8884d8"
          isAnimationActive={false}
          dot={false}
        />
        <XAxis dataKey="timestamp" />
        <YAxis domain={["auto", "auto"]} />
        <Tooltip />
      </LineChart>
    </ResponsiveContainer>
  );
}
```

## Animation Config

```tsx
<Line
  isAnimationActive={true} // default true, false for real-time/SSR
  animationBegin={0} // delay in ms
  animationDuration={1500} // duration in ms
  animationEasing="ease-in-out" // ease | ease-in | ease-out | ease-in-out | linear
  onAnimationStart={() => {}}
  onAnimationEnd={() => {}}
/>
```

## Performance Tips

```tsx
// Limit data points for smooth rendering
const MAX_POINTS = 500;
const chartData = data.slice(-MAX_POINTS);

// Use dot={false} for many data points
<Line dataKey="value" dot={false} />;

// Memoize expensive calculations
const processedData = useMemo(() => processChartData(rawData), [rawData]);

// Disable animation for real-time
<Line isAnimationActive={false} />;
```

## Anti-Patterns (FORBIDDEN)

```tsx
// NEVER: ResponsiveContainer without parent dimensions
<div>
  {" "}
  {/* No height! */}
  <ResponsiveContainer width="100%" height="100%">
    {" "}
    {/* Won't work */}
  </ResponsiveContainer>
</div>

// NEVER: Fixed dimensions on ResponsiveContainer
// NEVER: Animations on real-time charts (causes jank)
// NEVER: Inline data definition in render (new array every render)
// NEVER: Too many data points without limiting (performance issue)
```

## Key Decisions

| Decision      | Recommendation                                      |
| ------------- | --------------------------------------------------- |
| Container     | **ResponsiveContainer** always                      |
| Animation     | **Disabled** for real-time data                     |
| Tooltip       | **Custom** for branded UX, **formatter** for simple |
| Data updates  | **Sliding window** for time-series                  |
| Accessibility | **accessibilityLayer** is default `true` in 3.x — opt out with `accessibilityLayer={false}` |
| Multi-chart   | **syncId** to coordinate tooltips and brushes       |
| Stacking      | **stackId** prop on Bar/Area components             |

## Recharts 3.x Migration Notes

Breaking changes from 2.x to 3.x:

| Change | Details |
|--------|---------|
| `accessibilityLayer` | Now `true` by default (was `false` in 2.x) |
| Internal state removed | `Scatter.points`, `Area.points`, `Legend.payload`, `activeIndex` are no longer accessible via external API |
| `<Customized>` optional | Custom SVG components can be nested directly inside chart components without the `<Customized>` wrapper |
| Tooltip `portal` prop | New — renders tooltip in a custom DOM location to avoid overflow clipping |
| Min requirements | React 16.8+, TypeScript 5.x+, Node.js 18+, target ES6 |
| Keyboard events | No longer propagated through `onMouseMove` — use dedicated keyboard event handlers |
