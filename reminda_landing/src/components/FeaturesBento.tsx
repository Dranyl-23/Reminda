import { 
  FileText, 
  Smartphone, 
  ShieldAlert, 
  Sun, 
  Share2, 
  WifiOff,
  Sparkles
} from "lucide-react";

const iconMap: Record<string, any> = {
  FileText,
  Smartphone,
  ShieldAlert,
  Sun,
  Share2,
  WifiOff,
};

interface FeaturesBentoProps {
  features: Array<{ id: string; title: string; description: string; icon: string }>;
}

export function FeaturesBento({ features: featuresProp }: FeaturesBentoProps) {
  const features = featuresProp && featuresProp.length > 0 ? featuresProp : [];

  return (
    <div id="features" className="max-w-6xl mx-auto px-5 py-20">
      
      {/* Astroship Section Heading */}
      <div className="mt-8 md:mt-0">
        <h2 className="text-4xl lg:text-5xl font-bold lg:tracking-tight text-slate-900">
          Everything you need to master your schedule
        </h2>
        <p className="text-lg mt-4 text-slate-600 max-w-2xl leading-relaxed">
          Reminda comes packed with student-first innovations to keep your university semester smooth, on-time, and organized.
        </p>
      </div>

      {/* Astroship 6-Feature Grid */}
      <div className="grid sm:grid-cols-2 md:grid-cols-3 mt-16 gap-12 sm:gap-16">
        {features.map((feat, idx) => {
          const IconComponent = iconMap[feat.icon] || Sparkles;
          return (
            <div key={feat.id || idx} className="flex gap-4 items-start">
              <div className="mt-1 bg-black rounded-full p-2.5 w-10 h-10 shrink-0 flex items-center justify-center text-white">
                <IconComponent className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-semibold text-lg text-slate-900">
                  {feat.title}
                </h3>
                <p className="text-slate-500 mt-2 text-sm leading-relaxed">
                  {feat.description}
                </p>
              </div>
            </div>
          );
        })}
      </div>

    </div>
  );
}
