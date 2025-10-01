export default function Home() {
  return (
    <main className="min-h-screen bg-canvas">
      <div className="container mx-auto px-4 py-16">
        {/* Hero Section */}
        <div className="text-center max-w-4xl mx-auto mb-16">
          <h1 className="text-6xl font-bold text-textPrimary mb-6 font-heading">
            Volcy
          </h1>
          <p className="text-2xl text-textSecondary mb-8">
            Quantified skin progress, privately on your iPhone.
          </p>
          <div className="flex gap-4 justify-center">
            <a
              href="/waitlist"
              className="bg-mint text-white px-8 py-4 rounded-button font-semibold hover:opacity-90 transition-opacity"
            >
              Join Waitlist
            </a>
            <a
              href="/app"
              className="bg-surface text-textPrimary px-8 py-4 rounded-button font-semibold hover:bg-hairline transition-colors"
            >
              Sign In
            </a>
          </div>
        </div>

        {/* Features */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto">
          <FeatureCard
            title="Millimeter Accuracy"
            description="Per-lesion diameter, elevation, and volume measurements using on-device depth sensing."
            icon="📏"
          />
          <FeatureCard
            title="Privacy First"
            description="All ML inference happens on your iPhone. Your photos never leave your device."
            icon="🔒"
          />
          <FeatureCard
            title="Track Progress"
            description="Healing rates, redness trends, and regimen A/B testing to prove what works."
            icon="📊"
          />
        </div>

        {/* Footer */}
        <footer className="text-center mt-24 text-textSecondary">
          <p className="mb-4">Measure. Don&apos;t guess.</p>
          <div className="flex gap-6 justify-center">
            <a href="/privacy" className="hover:text-mint transition-colors">
              Privacy
            </a>
            <a href="/science" className="hover:text-mint transition-colors">
              Science
            </a>
            <a href="mailto:support@volcy.app" className="hover:text-mint transition-colors">
              Contact
            </a>
          </div>
        </footer>
      </div>
    </main>
  );
}

function FeatureCard({ title, description, icon }: { title: string; description: string; icon: string }) {
  return (
    <div className="bg-surface rounded-card p-8 shadow-card">
      <div className="text-5xl mb-4">{icon}</div>
      <h3 className="text-xl font-semibold text-textPrimary mb-2 font-heading">
        {title}
      </h3>
      <p className="text-textSecondary">{description}</p>
    </div>
  );
}
