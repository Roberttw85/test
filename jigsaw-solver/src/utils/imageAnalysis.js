/**
 * Image Analysis Utility for Jigsaw Puzzle Matching
 *
 * This module provides algorithms to analyze and compare images
 * based on color patterns, edge characteristics, and geometry.
 */

/**
 * Extract dominant colors from image data
 * @param {Array} pixels - Array of pixel data [r, g, b, a, ...]
 * @param {number} sampleSize - Number of pixels to sample
 * @returns {Array} Array of dominant color objects
 */
const extractDominantColors = (pixels, sampleSize = 100) => {
  const colorMap = {};
  const step = Math.max(1, Math.floor(pixels.length / 4 / sampleSize));

  for (let i = 0; i < pixels.length; i += step * 4) {
    const r = Math.round(pixels[i] / 32) * 32;
    const g = Math.round(pixels[i + 1] / 32) * 32;
    const b = Math.round(pixels[i + 2] / 32) * 32;
    const key = `${r},${g},${b}`;

    colorMap[key] = (colorMap[key] || 0) + 1;
  }

  return Object.entries(colorMap)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([color, count]) => {
      const [r, g, b] = color.split(',').map(Number);
      return { r, g, b, count };
    });
};

/**
 * Calculate color similarity between two color sets
 * @param {Array} colors1 - First color set
 * @param {Array} colors2 - Second color set
 * @returns {number} Similarity score (0-1)
 */
const calculateColorSimilarity = (colors1, colors2) => {
  if (!colors1.length || !colors2.length) return 0;

  let totalSimilarity = 0;
  const weights = colors1.map((_, i) => 1 / (i + 1)); // Weighted by dominance
  const totalWeight = weights.reduce((a, b) => a + b, 0);

  colors1.forEach((color1, i) => {
    let bestMatch = 0;
    colors2.forEach((color2) => {
      const distance = Math.sqrt(
        Math.pow(color1.r - color2.r, 2) +
        Math.pow(color1.g - color2.g, 2) +
        Math.pow(color1.b - color2.b, 2)
      );
      const similarity = 1 - distance / 441.67; // Max distance is sqrt(255^2 * 3)
      bestMatch = Math.max(bestMatch, similarity);
    });
    totalSimilarity += bestMatch * weights[i];
  });

  return totalSimilarity / totalWeight;
};

/**
 * Extract edge colors (border pixels) from image
 * @param {Array} pixels - Pixel data
 * @param {number} width - Image width
 * @param {number} height - Image height
 * @param {number} edgeWidth - Width of edge to sample
 * @returns {Object} Edge colors for each side
 */
const extractEdgeColors = (pixels, width, height, edgeWidth = 5) => {
  const edges = {
    top: [],
    bottom: [],
    left: [],
    right: [],
  };

  // Helper to get pixel at position
  const getPixel = (x, y) => {
    const idx = (y * width + x) * 4;
    return { r: pixels[idx], g: pixels[idx + 1], b: pixels[idx + 2] };
  };

  // Sample edge pixels
  for (let i = 0; i < width; i += Math.max(1, Math.floor(width / 20))) {
    for (let e = 0; e < edgeWidth; e++) {
      edges.top.push(getPixel(i, e));
      edges.bottom.push(getPixel(i, height - 1 - e));
    }
  }

  for (let i = 0; i < height; i += Math.max(1, Math.floor(height / 20))) {
    for (let e = 0; e < edgeWidth; e++) {
      edges.left.push(getPixel(e, i));
      edges.right.push(getPixel(width - 1 - e, i));
    }
  }

  return edges;
};

/**
 * Calculate average color of pixel array
 * @param {Array} pixels - Array of pixel objects
 * @returns {Object} Average color
 */
const averageColor = (pixels) => {
  if (!pixels.length) return { r: 0, g: 0, b: 0 };

  const sum = pixels.reduce(
    (acc, p) => ({ r: acc.r + p.r, g: acc.g + p.g, b: acc.b + p.b }),
    { r: 0, g: 0, b: 0 }
  );

  return {
    r: Math.round(sum.r / pixels.length),
    g: Math.round(sum.g / pixels.length),
    b: Math.round(sum.b / pixels.length),
  };
};

/**
 * Calculate edge compatibility between target hole and candidate piece
 * @param {Object} targetEdges - Edge colors of target
 * @param {Object} candidateEdges - Edge colors of candidate
 * @returns {number} Edge compatibility score (0-1)
 */
const calculateEdgeCompatibility = (targetEdges, candidateEdges) => {
  const compareEdges = (edge1, edge2) => {
    const avg1 = averageColor(edge1);
    const avg2 = averageColor(edge2);
    const distance = Math.sqrt(
      Math.pow(avg1.r - avg2.r, 2) +
      Math.pow(avg1.g - avg2.g, 2) +
      Math.pow(avg1.b - avg2.b, 2)
    );
    return 1 - distance / 441.67;
  };

  const scores = [
    compareEdges(targetEdges.top, candidateEdges.top),
    compareEdges(targetEdges.bottom, candidateEdges.bottom),
    compareEdges(targetEdges.left, candidateEdges.left),
    compareEdges(targetEdges.right, candidateEdges.right),
  ];

  return scores.reduce((a, b) => a + b, 0) / 4;
};

/**
 * Calculate brightness distribution similarity
 * @param {Array} pixels1 - First image pixels
 * @param {Array} pixels2 - Second image pixels
 * @returns {number} Similarity score (0-1)
 */
const calculateBrightnessDistribution = (pixels1, pixels2) => {
  const getBrightnessHistogram = (pixels) => {
    const histogram = new Array(10).fill(0);
    const step = Math.max(1, Math.floor(pixels.length / 4 / 100));
    let count = 0;

    for (let i = 0; i < pixels.length; i += step * 4) {
      const brightness = (pixels[i] + pixels[i + 1] + pixels[i + 2]) / 3;
      const bin = Math.min(9, Math.floor(brightness / 25.6));
      histogram[bin]++;
      count++;
    }

    return histogram.map((v) => v / count);
  };

  const hist1 = getBrightnessHistogram(pixels1);
  const hist2 = getBrightnessHistogram(pixels2);

  let similarity = 0;
  for (let i = 0; i < 10; i++) {
    similarity += Math.min(hist1[i], hist2[i]);
  }

  return similarity;
};

/**
 * Calculate texture similarity using simple variance analysis
 * @param {Array} pixels1 - First image pixels
 * @param {Array} pixels2 - Second image pixels
 * @returns {number} Similarity score (0-1)
 */
const calculateTextureSimilarity = (pixels1, pixels2) => {
  const getVariance = (pixels) => {
    const step = Math.max(1, Math.floor(pixels.length / 4 / 100));
    const values = [];

    for (let i = 0; i < pixels.length; i += step * 4) {
      values.push((pixels[i] + pixels[i + 1] + pixels[i + 2]) / 3);
    }

    const mean = values.reduce((a, b) => a + b, 0) / values.length;
    const variance = values.reduce((acc, v) => acc + Math.pow(v - mean, 2), 0) / values.length;

    return variance;
  };

  const var1 = getVariance(pixels1);
  const var2 = getVariance(pixels2);

  const maxVar = Math.max(var1, var2);
  if (maxVar === 0) return 1;

  return 1 - Math.abs(var1 - var2) / maxVar;
};

/**
 * Main analysis function - compares target image with candidate images
 * @param {Object} targetData - Target image data { pixels, width, height }
 * @param {Array} candidatesData - Array of candidate image data
 * @returns {Array} Sorted results with match scores
 */
export const analyzeImages = (targetData, candidatesData) => {
  const targetColors = extractDominantColors(targetData.pixels);
  const targetEdges = extractEdgeColors(
    targetData.pixels,
    targetData.width,
    targetData.height
  );

  const results = candidatesData.map((candidate, index) => {
    const candidateColors = extractDominantColors(candidate.pixels);
    const candidateEdges = extractEdgeColors(
      candidate.pixels,
      candidate.width,
      candidate.height
    );

    // Calculate various similarity metrics
    const colorScore = calculateColorSimilarity(targetColors, candidateColors);
    const edgeScore = calculateEdgeCompatibility(targetEdges, candidateEdges);
    const brightnessScore = calculateBrightnessDistribution(
      targetData.pixels,
      candidate.pixels
    );
    const textureScore = calculateTextureSimilarity(
      targetData.pixels,
      candidate.pixels
    );

    // Weighted composite score
    const overallScore =
      colorScore * 0.35 +      // Color matching is important
      edgeScore * 0.30 +       // Edge compatibility for puzzle fit
      brightnessScore * 0.20 + // Overall brightness pattern
      textureScore * 0.15;     // Texture consistency

    return {
      index,
      id: candidate.id,
      uri: candidate.uri,
      scores: {
        color: Math.round(colorScore * 100),
        edge: Math.round(edgeScore * 100),
        brightness: Math.round(brightnessScore * 100),
        texture: Math.round(textureScore * 100),
        overall: Math.round(overallScore * 100),
      },
      matchPercentage: Math.round(overallScore * 100),
    };
  });

  // Sort by overall score descending
  return results.sort((a, b) => b.matchPercentage - a.matchPercentage);
};

/**
 * Generate pixel data from base64 image (simulated for React Native)
 * In a real implementation, this would use canvas or native image processing
 * @param {string} base64 - Base64 image data
 * @returns {Promise<Object>} Image data with pixels
 */
export const generateSimulatedPixelData = (width = 100, height = 100) => {
  // Generate random but consistent pixel data for demo purposes
  const pixels = new Array(width * height * 4);

  for (let i = 0; i < pixels.length; i += 4) {
    pixels[i] = Math.floor(Math.random() * 256);     // R
    pixels[i + 1] = Math.floor(Math.random() * 256); // G
    pixels[i + 2] = Math.floor(Math.random() * 256); // B
    pixels[i + 3] = 255;                              // A
  }

  return { pixels, width, height };
};

/**
 * Create pixel data with a dominant color bias (for more realistic demos)
 * @param {Object} baseColor - Base color to bias towards
 * @param {number} variation - How much variation from base
 */
export const generateBiasedPixelData = (
  baseColor = { r: 128, g: 128, b: 128 },
  variation = 50,
  width = 100,
  height = 100
) => {
  const pixels = new Array(width * height * 4);

  for (let i = 0; i < pixels.length; i += 4) {
    pixels[i] = Math.max(0, Math.min(255, baseColor.r + (Math.random() - 0.5) * variation * 2));
    pixels[i + 1] = Math.max(0, Math.min(255, baseColor.g + (Math.random() - 0.5) * variation * 2));
    pixels[i + 2] = Math.max(0, Math.min(255, baseColor.b + (Math.random() - 0.5) * variation * 2));
    pixels[i + 3] = 255;
  }

  return { pixels, width, height };
};

export default {
  analyzeImages,
  generateSimulatedPixelData,
  generateBiasedPixelData,
};
