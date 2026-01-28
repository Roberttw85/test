import React, { createContext, useContext, useState } from 'react';

const ImageContext = createContext();

export const useImages = () => {
  const context = useContext(ImageContext);
  if (!context) {
    throw new Error('useImages must be used within an ImageProvider');
  }
  return context;
};

export const ImageProvider = ({ children }) => {
  const [targetImage, setTargetImage] = useState(null);
  const [candidateImages, setCandidateImages] = useState([]);
  const [analysisResults, setAnalysisResults] = useState(null);

  const addCandidateImage = (image) => {
    if (candidateImages.length < 10) {
      setCandidateImages((prev) => [...prev, { ...image, id: Date.now() }]);
    }
  };

  const removeCandidateImage = (id) => {
    setCandidateImages((prev) => prev.filter((img) => img.id !== id));
  };

  const resetAll = () => {
    setTargetImage(null);
    setCandidateImages([]);
    setAnalysisResults(null);
  };

  return (
    <ImageContext.Provider
      value={{
        targetImage,
        setTargetImage,
        candidateImages,
        setCandidateImages,
        addCandidateImage,
        removeCandidateImage,
        analysisResults,
        setAnalysisResults,
        resetAll,
      }}
    >
      {children}
    </ImageContext.Provider>
  );
};
