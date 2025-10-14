### Builder stage: install .NET SDK and tools
FROM fedora:latest AS builder

RUN dnf -y install curl tar gzip && dnf clean all

ENV DOTNET_INSTALL_DIR=/usr/share/dotnet
ENV DOTNET_ROOT=${DOTNET_INSTALL_DIR}
ENV PATH="$PATH:${DOTNET_INSTALL_DIR}:${DOTNET_INSTALL_DIR}/tools"

# Install .NET SDK 7.0
RUN curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
  && bash /tmp/dotnet-install.sh --channel 7.0 --install-dir ${DOTNET_INSTALL_DIR} \
  && rm -f /tmp/dotnet-install.sh

# Install dotnet-format into ${DOTNET_INSTALL_DIR}/tools so we can copy it into the final image
RUN mkdir -p ${DOTNET_INSTALL_DIR}/tools \
  && DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 ${DOTNET_INSTALL_DIR}/dotnet tool install --tool-path ${DOTNET_INSTALL_DIR}/tools dotnet-format


### Final stage: runtime image with Node.js, clang and the dotnet runtime/tools copied from builder
FROM fedora:latest

# Install runtime packages: Node.js (from Fedora), clang for formatting, git
RUN dnf -y install \
  git \
  nodejs \
  npm \
  clang \
  clang-tools-extra \
  curl \
  libicu \
  && dnf clean all

# Copy dotnet runtime + tools from builder
COPY --from=builder /usr/share/dotnet /usr/share/dotnet
COPY --from=builder /usr/share/dotnet/tools /usr/share/dotnet/tools

ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="$PATH:/usr/share/dotnet/tools:/usr/share/dotnet"

WORKDIR /usr/src/unreal-linter

# Copy rules and scripts into the image
COPY unreal-asset-name.csv ./
COPY scripts/ ./scripts/
COPY .clang-format ./
COPY .editorconfig ./

RUN chmod +x scripts/run_checks.sh

ENTRYPOINT ["./scripts/run_checks.sh"]
