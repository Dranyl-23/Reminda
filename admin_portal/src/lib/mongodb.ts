import dns from "dns";
import { MongoClient, MongoClientOptions } from "mongodb";

const PUBLIC_DNS_SERVERS = ["8.8.8.8", "1.1.1.1", "8.8.4.4", "1.0.0.1"];

function configureGlobalDns() {
  try {
    dns.setServers(PUBLIC_DNS_SERVERS);
    if (dns.promises && typeof dns.promises.setServers === "function") {
      dns.promises.setServers(PUBLIC_DNS_SERVERS);
    }
  } catch (_) {}
}

configureGlobalDns();

/**
 * Converts a `mongodb+srv://user:pass@clusterHost/db?params` URI into a direct
 * `mongodb://user:pass@shard1:27017,shard2:27017,shard3:27017/db?ssl=true&replicaSet=...`
 * seed-list URI so Node.js never fails with `querySrv ECONNREFUSED` when Windows/ISP
 * stub DNS (`127.0.0.1`) refuses SRV queries.
 */
async function resolveSrvUriToDirect(rawUri: string): Promise<string> {
  if (!rawUri.startsWith("mongodb+srv://")) {
    return rawUri;
  }

  try {
    const parsed = new URL(rawUri);
    const clusterHost = parsed.hostname;
    const srvRecordName = `_mongodb._tcp.${clusterHost}`;

    let srvTargets: Array<{ name: string; port: number }> = [];
    let txtParams = "";

    // 1. Try isolated UDP DNS Resolver (8.8.8.8 / 1.1.1.1)
    try {
      const resolver = new dns.promises.Resolver();
      resolver.setServers(PUBLIC_DNS_SERVERS);
      const [srvRecords, txtRecords] = await Promise.all([
        resolver.resolveSrv(srvRecordName),
        resolver.resolveTxt(clusterHost).catch(() => [] as string[][]),
      ]);
      srvTargets = srvRecords.map((r) => ({ name: r.name.replace(/\.$/, ""), port: r.port || 27017 }));
      txtParams = txtRecords.flat().join("&");
    } catch (_) {
      // 2. Fallback to Google DNS-over-HTTPS (TCP port 443) if UDP port 53 is blocked
      const [srvResp, txtResp] = await Promise.all([
        fetch(`https://dns.google/resolve?name=${encodeURIComponent(srvRecordName)}&type=SRV`).then((r) => r.json()),
        fetch(`https://dns.google/resolve?name=${encodeURIComponent(clusterHost)}&type=TXT`)
          .then((r) => r.json())
          .catch(() => ({ Answer: [] })),
      ]);

      if (Array.isArray(srvResp?.Answer)) {
        for (const ans of srvResp.Answer) {
          // SRV data format: "priority weight port target."
          const parts = String(ans.data || "").trim().split(/\s+/);
          if (parts.length >= 4) {
            const port = parseInt(parts[2], 10) || 27017;
            const target = parts[3].replace(/\.$/, "");
            srvTargets.push({ name: target, port });
          }
        }
      }
      if (Array.isArray(txtResp?.Answer)) {
        txtParams = txtResp.Answer.map((a: any) => String(a.data || "").replace(/^"|"$/g, "")).join("&");
      }
    }

    if (srvTargets.length === 0) {
      return rawUri;
    }

    const hostsSeedList = srvTargets.map((t) => `${t.name}:${t.port}`).join(",");
    const mergedParams = new URLSearchParams(txtParams);
    parsed.searchParams.forEach((val, key) => {
      mergedParams.set(key, val);
    });
    if (!mergedParams.has("ssl") && !mergedParams.has("tls")) {
      mergedParams.set("tls", "true");
    }
    if (!mergedParams.has("authSource")) {
      mergedParams.set("authSource", "admin");
    }

    const authPart = parsed.username
      ? `${parsed.username}${parsed.password ? `:${parsed.password}` : ""}@`
      : "";
    const pathname = parsed.pathname || "/";
    return `mongodb://${authPart}${hostsSeedList}${pathname}?${mergedParams.toString()}`;
  } catch (err) {
    console.warn("MongoDB SRV-to-Direct URI resolver fallback warning:", err);
    return rawUri;
  }
}

declare global {
  var _mongoClientPromise: Promise<MongoClient> | undefined;
}

const options: MongoClientOptions = {
  serverSelectionTimeoutMS: 10000,
  connectTimeoutMS: 10000,
};

async function createConnectedClient(): Promise<MongoClient> {
  const rawUri = process.env.MONGODB_URI;
  if (!rawUri) {
    throw new Error("MONGODB_URI environment variable is missing");
  }

  configureGlobalDns();
  const resolvedUri = await resolveSrvUriToDirect(rawUri);
  const client = new MongoClient(resolvedUri, options);
  return await client.connect();
}

export function getMongoClient(): Promise<MongoClient> {
  if (!global._mongoClientPromise) {
    global._mongoClientPromise = createConnectedClient().catch((err) => {
      // Evict rejected promise immediately so subsequent requests retry cleanly
      global._mongoClientPromise = undefined;
      throw err;
    });
  }
  return global._mongoClientPromise;
}

/**
 * Lazy PromiseLike wrapper around `getMongoClient()` so existing callers using
 * `const client = await clientPromise;` automatically get self-healing retry behavior.
 */
const clientPromise: Promise<MongoClient> = {
  then<TResult1 = MongoClient, TResult2 = never>(
    onfulfilled?: ((value: MongoClient) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null
  ): Promise<TResult1 | TResult2> {
    return getMongoClient().then(onfulfilled, onrejected);
  },
  catch<TResult = never>(
    onrejected?: ((reason: any) => TResult | PromiseLike<TResult>) | null
  ): Promise<MongoClient | TResult> {
    return getMongoClient().catch(onrejected);
  },
  finally(onfinally?: (() => void) | null): Promise<MongoClient> {
    return getMongoClient().finally(onfinally);
  },
  [Symbol.toStringTag]: "Promise",
};

export default clientPromise;
