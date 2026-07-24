import { prisma } from "./db.js";
import { config } from "./config.js";
import { AppError } from "./errors.js";

type OmdbMedia = {
  imdbID: string;
  Type: string;
  Title: string;
  Year: string;
  Plot?: string;
  Poster?: string;
  Genre?: string;
  Actors?: string;
  imdbRating?: string;
  totalSeasons?: string;
  Response: string;
  Error?: string;
};

const cacheMaxAge = 24 * 60 * 60 * 1000;

function normalized(item: OmdbMedia) {
  return {
    id: item.imdbID,
    type: item.Type,
    title: item.Title,
    year: Number.parseInt(item.Year) || null,
    plot: item.Plot && item.Plot !== "N/A" ? item.Plot : null,
    posterUrl: item.Poster && item.Poster !== "N/A" ? item.Poster : null,
    genres: item.Genre && item.Genre !== "N/A" ? item.Genre : null,
    cast: item.Actors && item.Actors !== "N/A" ? item.Actors : null,
    imdbRating: Number.parseFloat(item.imdbRating ?? "") || null,
    totalSeasons: Number.parseInt(item.totalSeasons ?? "") || null,
    rawJson: JSON.stringify(item),
    cachedAt: new Date()
  };
}

async function request(params: Record<string, string>) {
  if (!config.OMDB_API_KEY) throw new AppError(503, "OMDB_API_KEY is not configured");
  const query = new URLSearchParams({ apikey: config.OMDB_API_KEY, ...params });
  const response = await fetch(`https://www.omdbapi.com/?${query}`, {
    signal: AbortSignal.timeout(5000)
  });
  if (!response.ok) throw new AppError(502, "Movie service is unavailable");
  return response.json();
}

export async function findMedia(id: string) {
  const cached = await prisma.media.findUnique({ where: { id } });
  if (cached && Date.now() - cached.cachedAt.getTime() < cacheMaxAge) return cached;

  try {
    const item = (await request({ i: id, plot: "full" })) as OmdbMedia;
    if (item.Response === "False") throw new AppError(404, item.Error ?? "Media not found");
    return prisma.media.upsert({ where: { id }, update: normalized(item), create: normalized(item) });
  } catch (error) {
    if (cached) return cached;
    throw error;
  }
}

export async function searchMedia(query: string, page: number, type?: string) {
  try {
    const data = (await request({
      s: query,
      page: String(page),
      ...(type ? { type } : {})
    })) as { Search?: OmdbMedia[]; totalResults?: string; Response: string; Error?: string };
    if (data.Response === "False") return { items: [], total: 0, page };
    return {
      items: (data.Search ?? []).map(item => ({
        id: item.imdbID,
        type: item.Type,
        title: item.Title,
        year: Number.parseInt(item.Year) || null,
        posterUrl: item.Poster !== "N/A" ? item.Poster : null
      })),
      total: Number(data.totalResults ?? 0),
      page
    };
  } catch (error) {
    const cached = await prisma.media.findMany({
      where: { title: { contains: query } },
      take: 10,
      skip: (page - 1) * 10
    });
    if (cached.length) return { items: cached, total: cached.length, page, cached: true };
    throw error;
  }
}
